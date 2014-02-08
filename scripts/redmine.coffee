# Description:
#   Redmine
#
# Commands:
#
# URLS:
#   None.
#
# Notes:
#   None.

request = require('request')
url = require('url')
query = require('querystring')
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
    null

  getActivity: () ->
    @get PATH_ACTIVITY, null, 'atom', (error, response, feed) =>
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

  send: (msg) ->
    response = new @robot.Response(@robot, {user : {id : -1, name : @room}, text : "none", done : false}, [])
    # console.log @room + ':' + msg
    response.send msg

  # Private: do a GET request against the API
  get: (path, params, type = 'json', callback) ->
    path = "#{path}?#{query.stringify params}" if params?
    # console.log 'get: ' + path
    @request "GET", path, null, type, callback

  # Private: do a POST request against the API
  post: (path, body, type = 'json', callback) ->
    @request "POST", path, body, type, callback

  # Private: do a PUT request against the API
  put: (path, body, callback) ->
    @request "PUT", path, body, null, callback

  request: (method, path, body, type, callback) ->
    headers =
      "Content-Type": "application/json"
      "user-agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.52 Safari/537.36"
      "X-Redmine-API-Key": @token

    endpoint = url.parse(@url)
    pathname = endpoint.pathname.replace /^\/$/, ''

    options =
      "url"   : "#{endpoint.protocol}//#{endpoint.hostname}#{pathname}#{path}"
      "method" : method
      "headers": headers
      "timeout": 2000
      "strictSSL": false

    if method in ["POST", "PUT"]
      if typeof(body) isnt "string"
        body = JSON.stringify body

      options.headers["Content-Length"] = body.length

    # console.log options.url
    request options, (error, response, data) ->
      if !error and response?.statusCode is 200
        try
          if type is 'json'
            callback null, response, JSON.parse(data)
          else if type is 'atom'
            rssparser.parseString data, {}, (err, feed) ->
              # console.log feed
              callback err, response, feed
        catch err
          callback null, response, (data or { })
      else
        console.log 'error: ' + response?.statusCode
        console.log error
        @send "Redmine がなんかエラーやわ"
# }}}

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

