# Description:
#   Redmine
#
# Commands:
#   #99999 - チケットのタイトルとか URL を取ってくるよ.
#   hubot redmine (みんな|<nickname[,nickname]>) の実績
#
# URLS:
#   None.
#
# Notes:
#   None.

async = require('async')
request = require('request')
URL = require('url')
_ = require('underscore')
url = require('url')
QUERY = require('querystring')
cronJob = require('cron').CronJob
rssparser = require('rssparser')
DateUtil = require('date-utils')

PATH_ACTIVITY = process.env.HUBOT_REDMINE_ACTIVITY_URL

# {{{ SenpaiStorage
setSenpaiStorage = (robot, key, val) ->
  storage = robot.brain.data.senpaiStorage ||= {}
  storage[key] = val
#  msg.send "storage #{key}, #{val}"
  robot.brain.data.senpaiStorage = storage

getSenpaiStorage = (robot, key) ->
  storage = robot.brain.data.senpaiStorage ||= {}
  storage[key]
# }}}

# {{{ existsUser
existsUser = (robot, name) ->
  name = name.toLowerCase()
  return true if name is robot.name
  users = robot.brain.data.usersInfo ||= {}
  for u, v of users
    if u is name
      return true
  return false
# }}}

whoIsThis = (robot, name) -> # {{{
  name = name.toLowerCase()
  return name if existsUser robot, name
  gNicknames = getSenpaiStorage robot, 'NICKNAMES'
  gNicknames ||= {}
  return gNicknames[name] if gNicknames[name]
  return null
# }}}

# tries to resolve ambiguous users by matching login or firstname# {{{
# redmine's user search is pretty broad (using login/name/email/etc.) so
# we're trying to just pull it in a bit and get a single user
#
# name - this should be the name you're trying to match
# data - this is the array of users from redmine
#
# returns an array with a single user, or the original array if nothing matched
resolveUsers = (name, data) ->
    name = name.toLowerCase();

    # try matching login
    found = data.filter (user) -> user.login.toLowerCase() == name
    return found if found.length == 1

    # try first name
    found = data.filter (user) -> user.firstname.toLowerCase() == name
    return found if found.length == 1

    # give up
    data
# }}}

class Redmine # {{{
  constructor: (@robot, @room, @url, @token) ->
    endpoint = URL.parse(@url)
    @protocol = endpoint.protocol
    @hostname = endpoint.hostname
    @pathname = endpoint.pathname.replace /^\/$/, ''
    @url = "#{@protocol}//#{@hostname}#{@pathname}"

  Users: (params, callback, opt) ->
    @get "/users.json", params, opt, callback

  Issues: (params, callback, opt) ->
    @get "/issues.json", params, opt, callback

  Issue: (id) ->
    # console.log 'issue: ' + id
    show: (params, callback, opt) =>
      # console.log 'show: ' + id
      paramsDef = {include: "children"}
      params = _.extend(paramsDef, params);
      @get "/issues/#{id}.json", params, opt, (err, data, response) =>
        issue = data.issue
        childrenCnt = issue.children?.length || 0
        if childrenCnt is 0
          callback null, issue
        else
          f = _.object(issue.children.map (child) =>
            f2 = (cb) =>
              # console.log 'child' + child.id + ': ' + child.subject
              @Issue(child.id).show null, cb
            [child.id, f2])

          async.parallel f, (err, result) ->
            return callback err, null if err or result is null
            # console.log result
            issue.children = (v for k, v of result)
            callback null, issue

  TimeEntry: () ->
    get: (params, callback, opt) =>
      paramsDefault =
        from:  Date.yesterday().toFormat('YYYY-MM-DD')
        to:  Date.yesterday().toFormat('YYYY-MM-DD')
      params = _.extend(paramsDefault, params);
      @get "/time_entries.json", params, opt, (err, data, response) =>
        return callback err, null if err or data is null
        timeEntries = data.time_entries
        callback null, timeEntries

  getActivity: () -> # {{{
    @get PATH_ACTIVITY, null, {type: "atom"}, (error, feed, response) =>
      cacheActivities = getSenpaiStorage @robot, 'REDMINE_ACTIVITIES'
      cacheActivities ||= []
      dispcnt = 0
      items = feed.items

      for i, item of items
        break if dispcnt >= 5
        text = item.author + ': '
        text += item.title
        text += '(' + item.link + ')'
        text += '  ' + item.summary if item.summary
        text = text.replace /<("[^"]*"|'[^']*'|[^'">])*>/g, ''
        # console.log text
        continue if text in cacheActivities
        cacheActivities.push text
        @send "[Redmineタイムライン] #{text}"
        dispcnt++

      while cacheActivities.length > 100
        cacheActivities.shift()
      setSenpaiStorage @robot, 'REDMINE_ACTIVITIES', cacheActivities
# }}}

  # private send, get, post, put # {{{
  # Private: do a SEND
  send: (msg) ->
    response = new @robot.Response(@robot, {user : {id : -1, name : @room}, text : "none", done : false}, [])
    # console.log @room + ':' + msg
    response.send msg

  # Private: do a GET request against the API
  get: (path, params, opt, callback) ->
    path = "#{path}?#{QUERY.stringify params}" if params?
    # console.log 'get: ' + path
    @request "GET", path, null, opt, callback

  # Private: do a POST request against the API
  post: (path, body, opt, callback) ->
    @request "POST", path, body, opt, callback

  # Private: do a PUT request against the API
  put: (path, body, opt, callback) ->
    @request "PUT", path, body, opt, callback
# }}}

  # private request # {{{
  request: (method, path, body, opt, callback) ->
    optDefault =
      "type": "json"
    opt = _.extend(optDefault, opt)

    headers =
      "Content-Type": "application/json"
      "user-agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.52 Safari/537.36"
      "X-Redmine-API-Key": @token

    options =
      "url"   : "#{@url}#{path}"
      "method" : method
      "headers": headers
      "timeout": 10000
      "strictSSL": false

    if method in ["POST", "PUT"]
      if typeof(body) isnt "string"
        body = JSON.stringify body

      options.headers["Content-Length"] = body.length

    # console.log options.url
    request options, (err, response, data) ->
      if !err and response?.statusCode is 200
        try
          if opt.type is 'json'
            callback null, JSON.parse(data), response
          else if opt.type is 'atom'
            rssparser.parseString data, {}, (error, feed) ->
              # console.log feed
              callback error, feed, response
        catch err2
          callback null, (data or { }), response
      else
        console.log 'error: ' + response?.statusCode + ', url =>' + options.url
        console.log err ||= response?.statusCode
        #@send "Redmine がなんかエラーやわ"
        callback err, null, response
  # /private request }}}
# /Redmine }}}

module.exports = (robot) ->
  redmine = new Redmine robot, process.env.HUBOT_REDMINE_SEND_ROOM, process.env.HUBOT_REDMINE_BASE_URL, process.env.HUBOT_REDMINE_TOKEN

  checkUpdate = () ->
    getActivity()

  getActivity = () ->
    # console.log 'start Redmine getActivity!!!'
    redmine.getActivity()

  robot.respond /redmine activity/i, (msg) ->
    getActivity()

  # *(sec) *(min) *(hour) *(day) *(month) *(day of the week)
  new cronJob('*/10 * * * * *', () ->
    checkUpdate()
  ).start()

  robot.hear /.*(#(\d+)).*/, (msg) ->
    id = msg.match[1].replace /#/, ""
    return if isNaN id
    redmine.Issue(id).show null, (err, issue) ->
      return msg.send 'Error!: ' + err if err or issue is null
      # console.log issue.children
      url = "#{redmine.url}/issues/#{id}"
      estimated_hours = issue.estimated_hours || 0
      spent_hours = issue.spent_hours || 0
      for i, v of issue.children
        spent_hours += v.spent_hours || 0
      msg.send "#{url} : #{issue.subject}(予: #{estimated_hours}h / 消: #{spent_hours}h) - #{issue.project.name}"

  robot.respond /redmine[\s]+([\S]*)[\s]*実績(詳細)?/, (msg) ->
    command = msg.match[1]
    params =
      from:  Date.yesterday().toFormat('YYYY-MM-DD')
      to:  Date.yesterday().toFormat('YYYY-MM-DD')
    isDetail = true if msg.match[2]

    redmine.TimeEntry().get params, (err, timeEntries) ->
      return msg.send 'Error!: ' + err if err or timeEntries is null
      return msg.send "誰も実績入れてません!" unless timeEntries.length
      messages = {}
      for k, v of timeEntries
        id = v.user.id
        messages[id] ||=
          name: v.user.name
          hours: 0
        messages[id].hours += v.hours
        if isDetail
          messages[id].issues ||= {}
          messages[id].issues[v.issue.id] ||=
            hours: 0
            comments: ''
          messages[id].issues[v.issue.id].hours += v.hours
          if v.comments
            messages[id].issues[v.issue.id].comments += ',' if messages[id].issues[v.issue.id].comments
            messages[id].issues[v.issue.id].comments += v.comments

      reply = "#{params.from} 〜 #{params.to} の実績\n"
      for id, m of messages
         reply += "#{m.name}: #{m.hours}h\n"
         if isDetail
           for issueId, issue of m.issues
             reply += "  ##{issueId}: #{issue.hours}h #{issue.comments}\n"
      msg.send reply


#    userName = msg.match[1].toLowerCase()
#    user = whoIsThis robot, userName
#
#    redmine.Users name:user, (err, data) ->
#      # console.log 'count:' + userName + ' ' + data.total_count
#      unless data.total_count > 0
#        msg.reply "\"#{userName}\" が redmine で見つけられない"
#        return false
#
#      user = resolveUsers(user, data.users)[0]
#      console.log user

