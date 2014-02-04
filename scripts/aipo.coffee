# Description:
#   Aipo
#
# Commands:
#
# URLS:
#   None.
#
# Notes:
#   None.

request = require('request')
cheerio = require('cheerio')
url = require('url')
query = require('querystring')
cronJob = require('cron').CronJob

PATH_ACTIVITY = '/portal/media-type/html/user/h_sakaguchi_admin/page/default.psml/js_peid/P-143fe3e7fc1-10a40?action=controls.Maximize'

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

class Aipo
  constructor: (@robot, @room, @url, @user, @pass) ->
    @jar = request.jar()

  login: (callback) ->
    @get "/", {username: @user, password: @pass}, callback

  getActivity: () ->
    @login (error, response, $) =>
      @get PATH_ACTIVITY, null, (error, response, $) =>
        cacheActivities = getSenpaiStorage @robot, 'AIPO_ACTIVITIES'
        cacheActivities ||= []
        $('.auiRowTable tbody tr').each((i, elem) =>
          return if i > 5 or i is  0
          text = $(elem).text().replace /[\r\n]+/g, ','
          val = text.split(',')
          text = val[2] + ': ' + val[1]
          # a = $(elem).find('a')
          return if text in cacheActivities
          cacheActivities.push text
          @send "Aipo更新通知 #{text}"
        )
        while cacheActivities.length > 100
          cacheActivities.shift()
        setSenpaiStorage msg, 'AIPO_ACTIVITIES', cacheActivities

  send: (msg) ->
    response = new @robot.Response(@robot, {user : {id : -1, name : @room}, text : "none", done : false}, [])
    # console.log @room + ':' + msg
    response.send msg

  # Private: do a GET request against the API
  get: (path, params, callback) ->
    path = "#{path}?#{query.stringify params}" if params?
    # console.log 'get: ' + path
    @request "GET", path, null, callback

  # Private: do a POST request against the API
  post: (path, body, callback) ->
    @request "POST", path, body, callback

  # Private: do a PUT request against the API
  put: (path, body, callback) ->
    @request "PUT", path, body, callback

  request: (method, path, body, callback) ->
    headers =
      "Content-Type": "application/json"
      "user-agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.52 Safari/537.36"

    endpoint = url.parse(@url)
    pathname = endpoint.pathname.replace /^\/$/, ''

    options =
#      "host"   : endpoint.hostname
#      "port"   : endpoint.port
#      "path"   : "#{pathname}#{path}"
      "url"   : "#{endpoint.protocol}//#{endpoint.hostname}#{pathname}#{path}"
      "method" : method
      "headers": headers
      "timeout": 2000
      "strictSSL": false
      "jar": @jar

    # console.log options.url
    request options, (error, response, data) ->
      if !error and response?.statusCode is 200
        #console.log data
        $ = cheerio.load data
        callback null, response, $
      else
        console.log 'error: ' + response?.statusCode
        console.log error
        @send "Aipo がなんかエラーやわ"

module.exports = (robot) ->
  aipo = new Aipo robot, process.env.HUBOT_AIPO_SEND_ROOM, process.env.HUBOT_AIPO_BASE_URL, process.env.HUBOT_AIPO_USER, process.env.HUBOT_AIPO_PASSWORD

  getActivity = () ->
    console.log 'start getActivity!!!'
    aipo.getActivity()

  robot.respond /aipo activity/i, (msg) ->
    getActivity()

  # *(sec) *(min) *(hour) *(day) *(month) *(day of the week)
  new cronJob('10 * * * * *', () ->
    getActivity()
  ).start()

