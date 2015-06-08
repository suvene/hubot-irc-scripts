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
URL = require('url')
query = require('querystring')
cronJob = require('cron').CronJob

PATH_ACTIVITY = process.env.HUBOT_AIPO_ACTIVITY_URL
PATH_TIMELINE = process.env.HUBOT_AIPO_TIMELINE_URL

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
    endpoint = URL.parse(@url)
    @protocol = endpoint.protocol
    @hostname = endpoint.hostname
    @pathname = endpoint.pathname.replace /^\/$/, ''
    @url = "#{@protocol}//#{@hostname}#{@pathname}"

  login: (callback) ->
    @get "/", {username: @user, password: @pass}, callback

  getActivity: () ->
    @login (error, response, $) =>
      @get PATH_ACTIVITY, null, (error, response, $) =>
        cacheActivities = getSenpaiStorage @robot, 'AIPO_ACTIVITIES'
        cacheActivities ||= []
        dispcnt = 0
        $('.auiRowTable tbody tr').each((i, elem) =>
          return if dispcnt >= 5 or i is  0
          text = $(elem).text().replace /[\r\n]+/g, ','
          val = text.split(',')
          text = val[2] + ': ' + val[1]
          # a = $(elem).find('a')
          return if text in cacheActivities
          cacheActivities.push text
          @send "[Aipo更新情報] #{text}"
          dispcnt++
        )
        while cacheActivities.length > 100
          cacheActivities.shift()
        setSenpaiStorage @robot, 'AIPO_ACTIVITIES', cacheActivities

  getTimeline: () ->
    @login (error, response, $) =>
      @get PATH_TIMELINE, null, (error, response, $) =>
        cacheTimelines = getSenpaiStorage @robot, 'AIPO_TIMELINES'
        cacheTimelines ||= []
        dispcnt = 0
        $('.messageContents').each((i, elem) =>
          return if dispcnt >= 5
          name = $(elem).find('.name').text()
          return unless name
          a = $(elem).children().find('.body a')
          #console.log name + a
          return if a.length # 更新通知に表示されてるやつですから飛ばします
          body = $(elem).find('.body').text().replace(/[\r\n]+/g, '').replace(/[ ]+/g, ' ')
          text = "#{name}: #{body}"
          # console.log text
          val = text.split(',')
          return if text in cacheTimelines
          cacheTimelines.push text
          @send "[Aipoタイムライン] #{text}"
          dispcnt++
        )
        while cacheTimelines.length > 100
          cacheTimelines.shift()
        setSenpaiStorage @robot, 'AIPO_TIMELINES', cacheTimelines

        # console.log 'search like'
        cacheLikeCountMap = getSenpaiStorage @robot, 'AIPO_LIKE_COUNT_MAP'
        cacheLikeCountMap ||= {}
        # $(':div[id^=like]').each((i, elem) =>
        $('div').filter((i, elem) =>
          id = $(elem).attr('id')
          return id?.match /^like_[0-9]+/
        ).each((i, elem) =>
          id = $(elem).attr('id')
          count = $(elem).children('a').text()
          return if count is '0人'
          count = count.replace /人/g, ''
          target = $(elem).parent().prev()
          name = target.find('.name').text()
          # TODO: コメントのいいねの名前取得したい
          # name = $(elem).parent().find('.name').text() unless name
          return unless name
          body = $(target).find('.body').text().replace(/[\r\n]+/g, '').replace(/[ ]+/g, ' ')
          text = "#{name}: #{body}"
          prevCount = cacheLikeCountMap[id] ? 0
          return if prevCount is count
          if prevCount < count
            @send "[Aipoタイムライン]#{text} のイイネがつきました！"
          else
            @send "[Aipoタイムライン]#{text} のイイネが削除されました(T-T"

          # console.log 'prev: ' + prevCount + ' cur: ' + count + ' ' + id
          cacheLikeCountMap[id] = count
        )
        setSenpaiStorage @robot, 'AIPO_LIKE_COUNT_MAP', cacheLikeCountMap

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

    options =
#      "host"   : endpoint.hostname
#      "port"   : endpoint.port
#      "path"   : "#{pathname}#{path}"
      "url"   : "#{@url}#{path}"
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
        console.log 'aipo error: ' + response?.statusCode
        console.log error
        @send "Aipo がなんかエラーやわ"

module.exports = (robot) ->
  aipo = new Aipo robot, process.env.HUBOT_AIPO_SEND_ROOM, process.env.HUBOT_AIPO_BASE_URL, process.env.HUBOT_AIPO_USER, process.env.HUBOT_AIPO_PASSWORD

  checkUpdate = () ->
    getActivity()
    getTimeline()

  getActivity = () ->
#    console.log 'start getActivity!!!'
    aipo.getActivity()

  getTimeline = () ->
#    console.log 'start getTimeline!!!'
    aipo.getTimeline()

  robot.respond /aipo activity/i, (msg) ->
    getActivity()

  robot.respond /aipo timeline/i, (msg) ->
    getTimeline()

  # *(sec) *(min) *(hour) *(day) *(month) *(day of the week)
  new cronJob('*/30 * * * * *', () ->
    checkUpdate()
  ).start()

