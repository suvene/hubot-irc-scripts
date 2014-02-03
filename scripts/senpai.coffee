# Description:
#   manage user alias
#
# Commands:
#   hubot よろしくお願いします！ - hubot に挨拶しよう！
#   hubot 後輩の {nickname} - hubot に面通ししよう！
#   hubot 誰知ってるんですか? - hubot が知ってる人を教えてくれるよ！
#   hubot {アダ名 or nickname} って誰ですか？ - 誰かよくわからない場合は hubot に聞いてみよう！
#   hubot {nickname} のアダ名何ですか?  - ものしりな hubot にアダ名を教えてもらおう！
#   hubot {nickname} は {アダ名} って呼ばれてます - hubot にアダ名を教えるよ！
#   hubot {nickname} は {アダ名} って呼ばれてないです  - hubot にアダ名が間違いだったことを教えるよ！
#   {アダ名 or nickname}++  - イイネ！
#   {アダ名 or nickname}--  - ヨクナイネ！
#   hubot {アダ名 or nickname} 何点ですか?  - hubot に後輩の点数を教えてもらおう!

# {{{ AISATSU
AISATSU_YOROSHIKU = [
  'よろしくな'
  'まいど'
  '元気か？'
]

AISATSU_OHAYO = [
  'おう、おはよう。今日はがんばれよ'
  'おはよう、ちょっとネムいな'
  '今日飲みに行くか'
  'おはよう。今日金曜日だっけ？'
]
#}}}

NANDE_TAMEGUCHI = [# {{{
  'つか、何でタメ口なん？'
  '口のききかたに気をつけや'
]# }}}

# {{{ COUNT
COUNT_PLUS = [
  'すげーな！'
  '人気でてるぞ'
  'あんまり調子乗るなよ？'
]

COUNT_MINUS = [
  'どんまい、頑張ろうぜ'
  'まぁしょうがないな'
  '見返してやろうぜ'
]
# }}}

# {{{ existsUser
existsUser = (robot, msg, name) ->
  return true if name is robot.name
  users = robot.brain.data.usersInfo ||= {}
  for u, v of users
    if u is name
      return true
  return false
# }}}

# {{{ SenpaiStorage
setSenpaiStorage = (robot, msg, key, val) ->
  storage = robot.brain.data.senpaiStorage ||= {}
  storage[key] = val
#  msg.send "storage #{key}, #{val}"
  robot.brain.data.senpaiStorage = storage

getSenpaiStorage = (robot, msg, key) ->
  storage = robot.brain.data.senpaiStorage ||= {}
  storage[key]
# }}}

# {{{ UserInfo
setUserInfo = (robot, msg, name, key, val) ->
  return null unless existsUser robot, msg, name
  usersInfo = robot.brain.data.usersInfo ||= {}
  usersInfo[name] ||= {}
  usersInfo[name][key] = val
#  msg.send "usersInfo #{name}: #{key}, #{val}"
  robot.brain.data.usersInfo = usersInfo

getUserInfo = (robot, msg, name, key) ->
  return null unless existsUser robot, msg, name
  usersInfo = robot.brain.data.usersInfo ||= {}
  usersInfo[name] ||= {}
  usersInfo[name][key]
# }}}

whoIsThis = (robot, msg, name) -># {{{
  return name if existsUser robot, msg, name
  gNicknames = getSenpaiStorage robot, msg, 'NICKNAMES'
  gNicknames ||= {}
  return gNicknames[name] if gNicknames[name]
  return null
# }}}

# {{{ Keigo
REGEXP_KEIGO = '(です|デス|desu|ます|マス|masu|っす|ッス|ません|マセン|masen)か?[\?？!！]?'

isKeigo = (robot, msg) ->
  msg.message.match(REGEXP_KEIGO) isnt null

trimKeigo = (str) ->
  str.replace new RegExp('' + REGEXP_KEIGO + '$'), ''

checkKeigo = (robot, msg) =>
  unless isKeigo robot, msg
    msg.send msg.random NANDE_TAMEGUCHI if Math.random 0 < 0.1
# }}}

# {{{ Keisho
REGEXP_KEISHO = '(君|くん|クン|さん|サン|ちゃん|チャン)'
trimKeisho = (str) ->
  str.replace new RegExp('' + REGEXP_KEISHO + '$'), ''
# }}}

class History # {{{
  constructor: (@robot, @msg, @cache, @keep = 10) ->
    @cache ||= []

  add: (message) ->
    @cache.push message
    while @cache.length > @keep
      @cache.shift()
    @cache

  show: (lines) ->
    if (lines > @cache.length)
      lines = @cache.length
#    reply = 'Showing ' + lines + ' lines of history:\n'
    reply = reply + @entryToString(message) + '\n' for message in @cache[-lines..]
    return reply

  entryToString: (event) ->
    return '[' + event.month + '/' + event.date + ' ' + event.hours + ':' + event.minutes + '] ' + event.name + 'から: ' + event.message

  clear: ->
    @cache = []

class HistoryEntry
  constructor: (@name, @message) ->
    @time = new Date()
    @month = @time.getMonth() + 1
    if @month < 10
      @month = '0' + @month
    @date = @time.getDate()
    if @date < 10
      @date = '0' + @date
    @hours = @time.getHours()
    @minutes = @time.getMinutes()
    if @minutes < 10
      @minutes = '0' + @minutes
# }}}

module.exports = (robot) ->
  robot.brain.on 'loaded', =># {{{
    robot.brain.data.senpaiStorage ||= {}
    robot.brain.data.usersInfo ||= {}
# }}}

# {{{ あいさつ
  robot.respond /よろしく/, (msg) ->
    fromname = msg.message.user.name
    fromuser = whoIsThis robot, msg, fromname
    unless whoIsThis robot, msg, fromuser
      msg.send "#{fromuser} こいつ誰？ > all"
      checkKeigo robot, msg
      return
    msg.send msg.random AISATSU_YOROSHIKU
    checkKeigo robot, msg

  robot.respond /おはよう/, (msg) ->
    fromname = msg.message.user.name
    fromuser = whoIsThis robot, msg, fromname
    unless whoIsThis robot, msg, fromuser
      msg.send "#{fromuser} こいつ誰？ > all"
      checkKeigo robot, msg
      return
    msg.send msg.random AISATSU_OHAYO
# }}}

  robot.respond /後輩の[ ]*([^ ]+)/, (msg) -># {{{
    name = msg.match[1]
    name = trimKeigo name
    name = trimKeisho name
    if name is robot.name
      msg.send "それ俺だろw"
    else if existsUser robot, msg, name
      msg.send "知ってるしw"
    else
      robot.brain.data.usersInfo[name] = {}
      msg.send "#{name} か。よろしくな"

    checkKeigo robot, msg
    return
# }}}

  robot.respond /([^ ]+)[ ]*のことは忘れて/, (msg) -># {{{
    name = msg.match[1]
    name = trimKeigo name
    name = trimKeisho name
    if name is robot.name
      msg.send "俺は俺を忘れねぇ!"
    else unless existsUser robot, msg, name
      msg.send "いや、元々しらねーしw"
    else
      delete robot.brain.data.usersInfo[name]
      msg.send "#{name} か。新たな旅にでちまったんだなぁ……"
    checkKeigo robot, msg
    return
# }}}

  robot.respond /(誰|だれ)(知|し)って/, (msg) -># {{{
    users = robot.brain.data.usersInfo ||= {}
    ret = []
    for u, v of users
      ret.push u unless u is robot.name
    ret = ret.join('だろ, ')
    msg.send "えーっと #{ret} かな"
    checkKeigo robot, msg
# }}}

  robot.respond /([^ ]+)[ ]*って(誰|だれ)/, (msg) -># {{{
    name = msg.match[1]
    name = trimKeisho name
    user = whoIsThis robot, msg, name
    unless user?
      msg.send "#{user}？俺もしらねーなぁ"
      return

    if name is user
      msg.send "#{name} は #{name} だろ。大丈夫か？"
    else
      msg.send "#{name} は #{user} だのことだ。"
    checkKeigo robot, msg
# }}}

  robot.respond /([^ ]+)[ ]*のアダ名は?(何|なん|なに)/, (msg) -># {{{
    realname = msg.match[1]
    unless existsUser robot, msg, realname
      msg.send "#{realname} って誰？"
      checkKeigo robot, msg
      return

    nicknames = getUserInfo robot, msg, realname, 'NICKNAMES'
    nicknames ||= []
    unless nicknames.length
      msg.send "#{realname} は、特にアダ名無いよ。悲しいな"
      checkKeigo robot, msg
      return

    ret = []
    for u, v of nicknames
      ret.push v
    ret = ret.join('とか, ')
    msg.send "えーっと #{realname} は  #{ret} って呼ばれてるよ"
    checkKeigo robot, msg

# }}}

  robot.respond /([^ ]+)[ ]*は[ ]*([^ ]+)[ ]*(って|と)呼ばれ/, (msg) -># {{{
    return if msg.message.match('ない|ません')
    realname = msg.match[1]
    nickname = msg.match[2]
    nickname = trimKeisho nickname
    unless existsUser robot, msg, realname
      msg.send "#{realname} って誰？"
      checkKeigo robot, msg
      return

    gNicknames = getSenpaiStorage robot, msg, 'NICKNAMES'
    gNicknames ||= {}
    nicknames = getUserInfo robot, msg, realname, 'NICKNAMES'
    nicknames ||= []

    gRealname = gNicknames[nickname]
    if gRealname is realname
#      nicknames.push nickname
#      setUserInfo robot, msg, realname, 'NICKNAMES', nicknames
      msg.send '知ってるしw'
      checkKeigo robot, msg
      return
    else if gRealname? and gRealname isnt realname
      msg.send "それ #{gRealname} のアダ名やろ？"
      checkKeigo robot, msg
      return

    gNicknames[nickname] = realname
    setSenpaiStorage robot, msg, 'NICKNAMES', gNicknames
    nicknames.push nickname
    setUserInfo robot, msg, realname, 'NICKNAMES', nicknames
    msg.send 'ok. 了解'
    checkKeigo robot, msg
# }}}

  robot.respond /([^ ]+)[ ]*は[ ]*([^ ]+)[ ]*(って|と)呼ばれて(ない|ませ)/, (msg) -># {{{
    realname = msg.match[1]
    nickname = msg.match[2]
    nickname = trimKeisho nickname
    unless existsUser robot, msg, realname
      msg.send "そもそも #{realname} って誰?"
      checkKeigo robot, msg
      return

    gNicknames = getSenpaiStorage robot, msg, 'NICKNAMES'
    gNicknames ||= {}
    nicknames = getUserInfo robot, msg, realname, 'NICKNAMES'
    nicknames ||= []

    gRealname = gNicknames[nickname]
    if gRealname? and gRealname isnt realname
      msg.send "だってそれ #{gRealname} のアダ名やろ？"
      checkKeigo robot, msg
      return
    else unless nickname in nicknames
      msg.send "#{realname} が #{nickname} って呼ばれてるなんて聞いたことないでw"
      checkKeigo robot, msg
      return

    msg.send "え、まじで。だれやねん、嘘教えたやつ。"
    gn = gNicknames[nickname]

    gNicknames[nickname] = null
    setSenpaiStorage robot, msg, 'NICKNAMES', gNicknames
    newNicknames = (item for item in nicknames when item isnt nickname)
    setUserInfo robot, msg, realname, 'NICKNAMES', newNicknames
    checkKeigo robot, msg
# }}}

# {{{ plusplus
  robot.hear /([^ ]+)(\+\+[ ]*(.*))/i, (msg) ->
    fromname = msg.message.user.name
    fromuser = whoIsThis robot, msg, fromname
    unless whoIsThis robot, msg, fromuser
      msg.send "#{fromuser} こいつ誰？ > all"
      checkKeigo robot, msg
      return

    name = msg.match[1]
    name = trimKeisho name
    user = whoIsThis robot, msg, name
    reason = msg.match[2]

    unless user?
      msg.send "#{name} って誰？先に教えて"
      checkKeigo robot, msg
      return

    if user is fromuser
      msg.send "#{name} 自分で点数いれんなよ。悲しいやつだな"
      checkKeigo robot, msg
      return

    count = getUserInfo robot, msg, user, 'COUNT'
    count ||= 0
    count++
    setUserInfo robot, msg, user, 'COUNT', count

    count_history = getUserInfo robot, msg, user, 'COUNT_HISTORY'
    history = new History(robot, msg, count_history)
    historyentry = new HistoryEntry(fromuser, reason)
    count_history = history.add historyentry
    setUserInfo robot, msg, user, 'COUNT_HISTORY', count_history

    if user is robot.name
      msg.send "俺: #{count}点 サンキューな"
    else
      msg.send "#{name}: #{count}点 " + msg.random COUNT_PLUS
# }}}

# {{{ minusminus
  robot.hear /([^ ]+)(--[ ]*(.*))/i, (msg) ->
    fromname = msg.message.user.name
    fromuser = whoIsThis robot, msg, fromname
    unless whoIsThis robot, msg, fromuser
      msg.send "#{fromuser} こいつ誰？ > all"
      checkKeigo robot, msg
      return

    name = msg.match[1]
    name = trimKeisho name
    user = whoIsThis robot, msg, name
    reason = msg.match[2]

    unless user?
      msg.send "#{name} って誰？先に教えて"
      checkKeigo robot, msg
      return

    count = getUserInfo robot, msg, user, 'COUNT'

    count ||= 0
    count--
    setUserInfo robot, msg, user, 'COUNT', count

    count_history = getUserInfo robot, msg, user, 'COUNT_HISTORY'
    history = new History(robot, msg, count_history)
    historyentry = new HistoryEntry(fromuser, reason)
    count_history = history.add historyentry
    setUserInfo robot, msg, user, 'COUNT_HISTORY', count_history

    if user is robot.name
      msg.send "俺: #{count}点 まいったな"
    else
      msg.send "#{name}: #{count}点 " + msg.random COUNT_MINUS
# }}}

  robot.respond /([^ ]+)[ ]*何点/i, (msg) -># {{{
    name = msg.match[1]
    name = trimKeisho name
    user = whoIsThis robot, msg, name
    unless user?
      msg.send "#{name} ってしらねーなぁ"
      return

    count = getUserInfo robot, msg, user, 'COUNT'
    count ||= 0

    msg.send "#{name} は #{count}点だな"

    count_history = getUserInfo robot, msg, user, 'COUNT_HISTORY'
    history = new History(robot, msg, count_history, 5)
    msg.send history.show 5

    checkKeigo robot, msg
# }}}

