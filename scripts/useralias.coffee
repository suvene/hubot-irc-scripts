# Description:
#   manage user alias
#
# Commands:
#   hubot {アダ名} は {nickname} のアダ名  - hubot にアダ名を教えるよ！

existsUser = (robot, msg, name) ->
  users = robot.brain.users()
  for k, u of users
    if u.name is name
      msg.send u.name
      return true
  return false

module.exports = (robot) ->
  robot.respond /([^ ]+) は ([^ ]+) のアダ名/, (msg) ->
    msg.send "#{msg.match[2]}"
    unless existsUser robot, msg, msg.match[2]
      msg.send "#{msg.match[2]} とかいねーよ！？"
    msg.send "#{msg.match[1]} は #{msg.match[2]} のことですね"

