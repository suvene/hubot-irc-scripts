# Description:
#   manage user alias
#
# Commands:
#   hubot よろしくお願いします！ - hubot に挨拶しよう！
#   hubot 誰知ってるんですか? - hubot が知ってる人を教えてくれるよ！
#   hubot {name} は後輩です。よろしくお願いします! - hubot が知ってる人を教えてくれるよ！
#   hubot {アダ名} は {nickname} のアダ名です  - hubot いアダ名を教えるよ！
#   hubot {アダ名} は {nickname} のアダ名じゃないです  - hubot にアダ名が間違いだったことをを教えるよ！

aisatsu = [
  'よろしくな'
  'まいど'
  '元気か？'
]

nandeTameguchi = [
  'つか、何でタメ口なん？'
  '口のききかたに気をつけや'
]

existsUser = (robot, msg, name) ->
  users = robot.brain.data.usersInfo ||= {}
  for u, v of users
    if u is name
      return true
  return false

isKeigo = (robot, msg) ->
  msg.message.match('(です|デス|desu|ます|マス|masu|っす|ッス)か?[\?？!！]?') isnt null

checkKeigo = (robot, msg) =>
  msg.send msg.random nandeTameguchi unless isKeigo robot, msg

module.exports = (robot) ->
  robot.brain.on 'loaded', =>
    robot.brain.data.usersInfo ||= {}

  robot.respond /(よろしく)/, (msg) ->
    unless existsUser robot, msg, msg.message.user.name
      msg.send "#{msg.message.user.name} こいつ誰？ > all"
      checkKeigo robot, msg
      return
    msg.send msg.random aisatsu

  robot.respond /(誰知ってるん(です)?か?[\?？]?)/, (msg) ->
    users = robot.brain.data.usersInfo ||= {}
    ret = []
    for u, v of users
      ret.push u
    ret = ret.join('だろ, ')
    msg.send "えーっと #{ret} かな"
    checkKeigo robot, msg

  robot.respond /([^ ]+) は ([^ ]+) のアダ名/, (msg) ->
    return if msg.message.match('じゃない')
    nick = msg.match[1]
    name = msg.match[2]
    unless existsUser robot, msg, name
      msg.send "#{name} とか知らねーよ!"
      checkKeigo robot, msg
      return

    usersInfo = robot.brain.data.usersInfo["#{name}"] ||= []
    if nick in usersInfo
      msg.send "知ってるしw"
      checkKeigo robot, msg
      return

    usersInfo.push nick
    msg.send "#{msg.match[1]} は #{msg.match[2]} のことか。#{robot.name} 覚えた!"

  robot.respond /([^ ]+) は ([^ ]+) のアダ名(じゃない)/, (msg) ->
    nick = msg.match[1]
    name = msg.match[2]
    unless existsUser robot, msg, name
      msg.send "そもそも #{name} って誰?"
      checkKeigo robot, msg
      return

    msg.send "え、まじで。だれやねん、嘘教えたやつ。"
    users = robot.brain.data.usersInfo
    delete users[name]
