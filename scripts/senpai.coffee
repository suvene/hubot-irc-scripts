# Description:
#   manage user alias
#
# Commands:
#   hubot よろしくお願いします！ - hubot に挨拶しよう！
#   hubot 誰知ってるんですか? - hubot が知ってる人を教えてくれるよ！
#   hubot 後輩の {nickname} - hubot に面通ししよう！
#   hubot {nickname} のアダ名何ですか?  - ものしりな hubot にアダ名を教えiてもらおう！
#   hubot {アダ名} は {nickname} のアダ名です  - hubot にアダ名を教えるよ！
#   hubot {アダ名} は {nickname} のアダ名じゃないです  - hubot にアダ名が間違いだったことをを教えるよ！
#   {アダ名 or nickname}++  - イイネ！
#   {アダ名 or nickname}--  - ヨクナイネ！

AISATSU = [# {{{
  'よろしくな'
  'まいど'
  '元気か？'
]# }}}

NANDE_TAMEGUCHI = [# {{{
  'つか、何でタメ口なん？'
  '口のききかたに気をつけや'
]# }}}

COUNT_PLUS = [
  'すげーな！'
  '人気でてるぞ'
]

# {{{ existsUser
existsUser = (robot, msg, name) ->
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
REGEXP_KEIGO = '(です|デス|desu|ます|マス|masu|っす|ッス)か?[\?？!！]?'

isKeigo = (robot, msg) ->
  msg.message.match(REGEXP_KEIGO) isnt null

trimKeigo = (str) ->
  str.replace new RegExp('' + REGEXP_KEIGO + '$'), ''

checkKeigo = (robot, msg) =>
  msg.send msg.random NANDE_TAMEGUCHI unless isKeigo robot, msg
# }}}

module.exports = (robot) ->
  robot.brain.on 'loaded', =># {{{
    robot.brain.data.senpaiStorage ||= {}
    robot.brain.data.usersInfo ||= {}
# }}}

  robot.respond /よろしく/, (msg) -># {{{
    unless existsUser robot, msg, msg.message.user.name
      msg.send "#{msg.message.user.name} こいつ誰？ > all"
      checkKeigo robot, msg
      return
    msg.send msg.random AISATSU
    checkKeigo robot, msg
# }}}

  robot.respond /誰知って/, (msg) -># {{{
    users = robot.brain.data.usersInfo ||= {}
    ret = []
    for u, v of users
      ret.push u
    ret = ret.join('だろ, ')
    msg.send "えーっと #{ret} かな"
    checkKeigo robot, msg
# }}}

  robot.respond /後輩の ([^ ]+)/, (msg) -># {{{
    name = msg.match[1]
    name = trimKeigo name
    if existsUser robot, msg, name
      msg.send "知ってるしw"
      checkKeigo robot, msg
      return
    robot.brain.data.usersInfo[name] = {}
    msg.send "#{name} か。よろしくな"
# }}}

  robot.respond /([^ ]+) のアダ名何/, (msg) -># {{{
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

  robot.respond /([^ ]+) は ([^ ]+) のアダ名/, (msg) -># {{{
    return if msg.message.match('じゃない')
    nickname = msg.match[1]
    realname = msg.match[2]
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

  robot.respond /([^ ]+) は ([^ ]+) のアダ名(じゃない)/, (msg) -># {{{
    nickname = msg.match[1]
    realname = msg.match[2]
    unless existsUser robot, msg, realname
      msg.send "そもそも #{realname} って誰?"
      checkKeigo robot, msg
      return

    gNicknames = getSenpaiStorage robot, msg, 'NICKNAMES'
    gNicknames ||= {}
    nicknames = getUserInfo robot, msg, realname, 'NICKNAMES'
    nicknames ||= []

    unless nickname in nicknames
      msg.send "#{realname} は #{nickname} なんて呼ばれてないで"
      checkKeigo robot, msg
      return

    msg.send "え、まじで。だれやねん、嘘教えたやつ。"
    gn = gNicknames[nickname]

    gNicknames[nickname] = null
    setSenpaiStorage robot, msg, 'NICKNAMES', gNicknames
    newNicknames = (item for item in nicknames when item isnt nickname)
    msg.send "nick #{newNicknames}"
    setUserInfo robot, msg, realname, 'NICKNAMES', newNicknames
    checkKeigo robot, msg
# }}}

# {{{ plusplus
  robot.hear /([^ ]+)\+\+/i, (msg) ->
    name = msg.match[1]

    user = whoIsThis robot, msg, name
    unless user?
      msg.send "#{realname} って誰？先に教えて"
      return

    count = getUserInfo robot, msg, user, 'COUNT'
    count ||= 0
    count++
    setUserInfo robot, msg, user, 'COUNT', count

    msg.send "#{name}: #{count}点 " + msg.random COUNT_PLUS
# }}}


