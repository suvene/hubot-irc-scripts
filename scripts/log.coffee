# Desjcription:
#   LOG
#
# Commands:
#
fs = require 'fs'
mkdirp = require 'mkdirp'
PATH_LOG_ROOT = process.env.HUBOT_LOG_ROOT

module.exports = (robot) ->

# {{{ log
  robot.adapter.bot.on 'raw', (message) ->
    switch message.rawCommand
      when 'NOTICE', 'PRIVMSG', 'PART', 'JOIN', 'TOPIC'
        channel = message.args[0].replace /^#/, ''
        dtm = new Date
        year = dtm.getFullYear()
        month = ('0' + (dtm.getMonth() + 1)).slice(-2)
        date = ('0' + dtm.getDate()).slice(-2)
        hours = ('0' + dtm.getHours()).slice(-2)
        minutes = ('0' + dtm.getMinutes()).slice(-2)
        seconds = ('0' + dtm.getSeconds()).slice(-2)

        ymd = year + '/' + month + '/' + date
        ymdhms = ymd + ' ' + hours + ':' + minutes + ':' + seconds

        #logContent = (JSON.stringify {
          #command: message.rawCommand,
          #args: message.args,
          #time: time,
          #nick: message.nick
        #}) + ",\n"

        command = message.rawCommand
        nick = message.nick
        arg1 = message.args[1] || ''

        logContent = "#{ymdhms}\t#{command}\t#{nick}\t#{arg1}\n"
        dir = "#{PATH_LOG_ROOT}/#{channel}"

        log = () ->
          #fs.appendFile "#{dir}/#{year}-#{month}-#{date}.log", logContent, console.log.bind console
          fs.appendFile "#{dir}/#{year}-#{month}-#{date}.log", logContent, 'utf8'
        fs.exists(dir, (exists)->
          if exists
            log()
          else
            mkdirp dir, log
        )
# }}}

