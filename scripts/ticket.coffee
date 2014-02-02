# Description:
#   get a ticket url
#
# Commands:
#   #99999 - チケットのURLを取ってくるよ.(タイトルはまだない)

module.exports = (robot) ->
  robot.hear /#([0-9]+)/, (msg) ->
    msg.send 'http;//192.168.1.150/issues/' + msg.match[1]

