# Description:
#   Redmine
#
# Commands:
#   #99999 - チケットのタイトルとか URL を取ってくるよ.
#   hubot redmine (みんな|<nickname[,nickname]>) の実績[詳細] - 前営業日の実績を教えてもらおう！
#   hubot redmine 実績チェック - 前営業日の実績をチェックするよ！
#   hubot redmine <nickname> 実績チェック(する|しない) - 実績チェックの対象、または対象外にするよ！
#   hubot redmine [yyyy-mm-dd] <#9999> 99[.25](h|時間) <活動> [コメント]- 実績を登録しよう！(日付省略時は前営業日になるよ) 例) hubot redmine #41 1.25h 製造 働いたよ!
#
# URLS:
#   None.
#
# Notes:
#   None.

URL = require('url')
QUERY = require('querystring')
request = require('request')
async = require('async')
rssparser = require('rssparser')
cronJob = require('cron').CronJob
_ = require('underscore')
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

# {{{ UserInfo
setUserInfo = (robot, name, key, val) ->
  name = name.toLowerCase()
  return null unless existsUser robot, name
  usersInfo = robot.brain.data.usersInfo ||= {}
  usersInfo[name] ||= {}
  usersInfo[name][key] = val
  robot.brain.data.usersInfo = usersInfo

getUserInfo = (robot, name, key) ->
  name = name.toLowerCase()
  return null unless existsUser robot, name
  usersInfo = robot.brain.data.usersInfo ||= {}
  usersInfo[name] ||= {}
  usersInfo[name][key]
# }}}

getPrevKadobi = (robot, date) -> # {{{
  # console.log 'getPrevKadobi: ' + date.toYMD()
  loop
    week = date.getDay()
    gHolidays = getSenpaiStorage robot, 'HOLIDAYS'
    # console.log "week: #{week}"
    if week is 0 or week is 6 or gHolidays[date.toYMD()]
      date = date.addDays(-1)
      continue
    break
  return date
# }}}

getActivityId = (activity) -> # {{{
  return 8 if activity.match /要件定義/
  return 9 if activity.match /製造/
  return 10 if activity.match /管理/
  return 11 if activity.match /結テ仕/
  return 12 if activity.match /調査/
  return 13 if activity.match /見積/
  return 14 if activity.match /リリース/
  return 15 if activity.match /ヒアリング/
  return 16 if activity.match /開発環境/
  return 17 if activity.match /オペマニ/
  return 18 if activity.match /営業/
  return 24 if activity.match /社内手続き/
  return 25 if activity.match /現状分析/
  return 26 if activity.match /教育/
  return 27 if activity.match /社内環境/
  return 28 if activity.match /業務外作業/
  return 29 if activity.match /引継/
  return 30 if activity.match /土曜出勤/
  return 31 if activity.match /提案活動/
  return 32 if activity.match /単テ仕/
  return 33 if activity.match /単テ実/
  return 34 if activity.match /基本設計/
  return 35 if activity.match /詳細設計/
  return 37 if activity.match /結テ実/
  return 38 if activity.match /PMO/
  return 39 if activity.match /ユーザー環境/
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
  constructor: (@robot, @room, @url, @token) -> # {{{
    endpoint = URL.parse(@url)
    @protocol = endpoint.protocol
    @hostname = endpoint.hostname
    @pathname = endpoint.pathname.replace /^\/$/, ''
    @url = "#{@protocol}//#{@hostname}#{@pathname}"
  # }}}

  Users: (params, callback, opt) -> # {{{
    @get "/users.json", params, opt, callback
# }}}

  Issues: (params, callback, opt) -> # {{{
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
  # }}}

  TimeEntry: () -> # {{{
    get: (params, callback, opt) =>
      console.log 'TimeEntry#get'
      paramsDefault =
        from:  Date.yesterday().toFormat('YYYY-MM-DD')
        to:  Date.yesterday().toFormat('YYYY-MM-DD')
      params = _.extend(paramsDefault, params);
      @get "/time_entries.json", params, opt, (err, data, response) =>
        return callback err, null if err or data is null
        timeEntries = data.time_entries
        callback null, timeEntries

    create: (attributes, callback, opt) =>
      @post "/time_entries.json", {time_entry: attributes, su_userid: attributes.su_userid}, opt, callback
# }}}

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
        if item.summary
          summary = item.summary.replace /<("[^"]*"|'[^']*'|[^'">])*>/g, ''
          # console.log summary
          matches = summary.match /([\r\n]*)([^\r\n]*)([\r\n]*)?(.*)/
          text += '  ' + matches[2] if matches[2]
          text += '...つづく...' if matches[4]
          # console.log 'matches[1]:' + matches[1]
          # console.log 'matches[2]:' + matches[2]
          # console.log 'matches[4]:' + matches[4]
        text = text.replace /<("[^"]*"|'[^']*'|[^'">])*>/g, ''
        text = text.substring(256)
        # console.log text
        continue if text in cacheActivities
        cacheActivities.push text
        @send "[Redmineタイムライン] #{text}"
        dispcnt++

      while cacheActivities.length > 100
        cacheActivities.shift()
      setSenpaiStorage @robot, 'REDMINE_ACTIVITIES', cacheActivities
# }}}

  checkJisseki: (date) -> # {{{
    console.log 'checkJisseki'
    usersInfo = @robot.brain.data.usersInfo ||= {}
    users = {}
    userCnt = 0
    for u, v of usersInfo
      continue if v['IS_NOT_CHECK_JISSEKI'] or u is @robot.name
      userCnt++
      console.log "check user: #{u}"
      users[u] =
        errNoInput: true
        warnNoActivity: false
    return unless userCnt

    params =
      from: date.toYMD()
      to: date.toYMD()

    @TimeEntry().get params, (err, timeEntries) =>
      @send 'Error!: ' + err if err or timeEntries is null
      for k, v of timeEntries
        name = whoIsThis @robot, v.user.name
        unless name
          name = v.user.name
          users[name] = {}
          users[name].warnWho = true
        users[name]?.errNoInput = false if users[name]?.errNoInput
        users[name]?.warnNoActivity = true if v.activity.name is '【設定してください】'

      reply = "#{params.from} の実績チェック\n"
      for k, v of users
        if v.errNoInput or v.warnNoActivity or v.warnWho
          reply += "#{k}: "
          reply += "<だれかわからない>" if v.warnWho
          reply += "<実績入力なし>" if v.errNoInput
          reply += "<活動が設定されてない実績あり>" if v.warnNoActivity
          reply += "\n"

      @send reply
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
      options.body = body
      # options.headers["Content-Length"] = body.length

    # console.log options.url
    request options, (err, response, data) ->
      if !err and response?.statusCode is 200
        parsedData = data
        try
          parsedData = JSON.parse(data)

        if opt.type is 'json'
          callback null, (parsedData or { }), response
        else if opt.type is 'atom'
          rssparser.parseString data, {}, (error, feed) ->
            # console.log feed
            callback error, feed, response
      else
        console.log 'code: ' + response?.statusCode + ', url =>' + options.url
        console.log err ||= response?.statusCode
        callback err, data, response
  # /private request }}}
# /Redmine }}}

module.exports = (robot) ->
  redmine = new Redmine robot, process.env.HUBOT_REDMINE_SEND_ROOM, process.env.HUBOT_REDMINE_BASE_URL, process.env.HUBOT_REDMINE_TOKEN

  # {{{ for cron
  checkUpdate = () ->
    getActivity()

  getActivity = () ->
    # console.log 'start Redmine getActivity!!!'
    redmine.getActivity()

  robot.respond /redmine activity/i, (msg) ->
    getActivity()

  checkJisseki = (date) ->
    redmine.checkJisseki(date)

  # *(sec) *(min) *(hour) *(day) *(month) *(day of the week)
  new cronJob('*/10 * * * * *', () ->
    checkUpdate()
  ).start()

  new cronJob('0 15 9,12,15,18 * * *', () ->
    date = getPrevKadobi(robot, Date.yesterday())
    checkJisseki(date)
  ).start()
  # }}}

  robot.respond /redmine [\s]*([\S]*)[\s]*(?:は|を|の)?(?:実績)?(?:check|チェック)(?:実績)?(する|して|しない)?/i, (msg) -> # {{{
    name = msg.match[1].replace /(実績|チェック)/, ''
    flg = msg.match[2]
    if name and flg
      user = whoIsThis robot, name
      return msg.send "#{name} は\"面通し\"されてない" unless user
      isNotCheck = false
      isNotCheck = true if flg.match /(しない)/
      setUserInfo robot, user, 'IS_NOT_CHECK_JISSEKI', isNotCheck
      msg.send "次から #{user} の実績チェック#{flg}!"
    else
      date = getPrevKadobi(@robot, Date.yesterday())
      checkJisseki date
  # }}}

  robot.hear /.*(#(\d+)).*/, (msg) -> # {{{
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
  # }}}

  robot.respond /redmine[\s]+([\S]*)[\s]*実績(詳細)?/, (msg) -> # {{{
    command = msg.match[1]
    return if msg.message.match /(check|チェック)/
    d = getPrevKadobi(robot, Date.yesterday())
    params =
      from: d.toYMD()
      to: d.toYMD()
    isDetail = true if msg.match[2]

    redmine.TimeEntry().get params, (err, timeEntries) ->
      return msg.send 'Error!: ' + err if err or timeEntries is null
      return msg.send "#{params.from} 〜 #{params.to} に誰も実績入れてません!" unless timeEntries.length
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
  # }}}

  robot.respond /redmine[\s]+(\d{2,4}(?:-|\/)\d{1,2}(?:-|\/)\d{1,2}[\s]+)?#(\d+)[\s]+(\d{1,2}(\.00?|\.25|\.50?|.75)?)[\s]*(?:h|時間)[\s]+([\S]+)(?:[\s]+"?([^"]+)"?)?/i, (msg) -> # {{{
    userName = msg.message.user.name
    user = whoIsThis robot, userName
    return msg.send "誰？" unless user

    [date, id, hours, hoursshosu, activity, userComments] = msg.match[1..6]
    if date
      date = new Date date
      return msg.send "#{date} は日付じゃない" unless Date.validateDay(date.getDate(), date.getFullYear(), date.getMonth())
    else
      date = getPrevKadobi robot, Date.yesterday()
    dateYMD = date.toYMD()
    console.log dateYMD

    if userComments?
      comments = "#{userComments}"
    else
      comments = "Time logged by: #{msg.message.user.name}"
    activityId = getActivityId activity
    unless activityId
      msg.reply "こんな\"活動\"はない > #{activity}\n"
      msg.send " Usage: #{robot.name} redmine ##{id} #{hours}h 製造 #{activity}"
      return

    redmine.Users name:user, (err, data) =>
      # console.log 'count:' + userName + ' ' + data.total_count
      unless data.total_count > 0
        msg.send "\"#{user}\" が redmine で見つけられない"
        return false
      redmineUser = resolveUsers(user, data.users)[0]

      attributes =
        issue_id: id
        spent_on: dateYMD
        hours: hours
        comments: comments
        su_userid: redmineUser.id
        activity_id: activityId

      redmine.TimeEntry().create attributes, (error, data, response) ->
        if response?.statusCode == 201
          msg.reply "よく頑張りました！(#{dateYMD} で登録)"
        else
          msg.reply "なんか失敗"
# }}}

