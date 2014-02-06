# Desjcription:
#   IRC API
#   @see http-say.coffee
#   @see http-post-say.coffee
#
# Commands:
#
# URLS:
#   GET /hubot/irc/send?message=<message>[&room=<room>&type=<type]
#   POST /hubot/irc/send
#     message = <message>
#     room = <room>
#
#   curl -X POST http://localhost:8080/hubot/send -d message=lala -d room='#dev'
#

querystring = require('querystring')

createUser = (robot, room, type) ->
  console.log room
  user = robot.brain.userForId 'broadcast'
  user.room = room if room
  user.type = type ? 'groupchat'
  return user

send = (robot, res, user, message) ->
  if message
    robot.send user, "#{message}"

  robot.logger.info "Message '#{message}' received for room #{user.room}"

  res.writeHead 200, {'Content-Type': 'text/plain'}
  res.end "send #{message}"


module.exports = (robot) ->
  robot.router.get "/irc/send", (req, res) ->
    query = querystring.parse(req._parsedUrl.query)

    room = '#' + query.room if query.room
    user = createUser robot, room, query.type
    message = query.message

    send robot, res, user, message

  robot.router.post "/irc/send", (req, res) ->

    user = createUser robot, req.body.room, req.body.type
    message = req.body.message

    send robot, res, user, message

