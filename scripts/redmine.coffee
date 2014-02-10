# Description:
#   Redmine
#
# Commands:
#   #99999 - チケットのタイトルとか URL を取ってくるよ.
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

class Redmine # {{{
  constructor: (@robot, @room, @url, @token) ->
    endpoint = URL.parse(@url)
    @protocol = endpoint.protocol
    @hostname = endpoint.hostname
    @pathname = endpoint.pathname.replace /^\/$/, ''
    @url = "#{@protocol}//#{@hostname}#{@pathname}"

  Issues: (params, callback) ->
    @get "/issues.json", params, {type: "json"}, callback

  Issue: (id) ->
    # console.log 'issue: ' + id
    show: (params, callback, opt) =>
      # console.log 'show: ' + id
      paramsDef = {include: "children"}
      params = _.extend(paramsDef, params);
      optDef =
        type: "json"
      opt = _.extend(optDef, opt);
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
            return if err
            # console.log result
            issue.children = (v for k, v of result)
            callback null, issue

  TimeEntry: (issueId, id = null) ->
    get "/issues/#{id}/time_entiry"

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
    request options, (error, response, data) ->
      if !error and response?.statusCode is 200
        try
          if opt.type is 'json'
            callback null, JSON.parse(data), response
          else if opt.type is 'atom'
            rssparser.parseString data, {}, (err, feed) ->
              # console.log feed
              callback err, feed, response
        catch err
          callback null, (data or { }), response
      else
        console.log 'error: ' + response?.statusCode
        console.log error
        @send "Redmine がなんかエラーやわ"
        callback error, null, response
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
    redmine.Issue(id).show null, (err, issue, response) ->
      # console.log issue.children
      url = "#{redmine.url}/issues/#{id}"
      estimated_hours = issue.estimated_hours || 0
      spent_hours = issue.spent_hours || 0
      for i, v of issue.children
        spent_hours += v.spent_hours || 0
      msg.send "#{url} : #{issue.subject}(予: #{estimated_hours}h / 消: #{spent_hours}h) - #{issue.project.name}"

