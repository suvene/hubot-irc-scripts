# Desjcription:
#   LOG
#
# Commands:
#
fs = require 'fs'
mkdirp = require 'mkdirp'
mysql = require 'mysql'
PATH_LOG_ROOT = process.env.HUBOT_LOG_ROOT

module.exports = (robot) ->

  @client = null

# {{{ log
  robot.adapter.bot.on 'raw', (msg) ->
    switch msg.rawCommand
      when 'NOTICE', 'PRIVMSG', 'PART', 'JOIN', 'TOPIC'
        channel = msg.args[0].replace /^#/, ''
        dtm = new Date
        year = dtm.getFullYear()
        month = ('0' + (dtm.getMonth() + 1)).slice(-2)
        date = ('0' + dtm.getDate()).slice(-2)
        hours = ('0' + dtm.getHours()).slice(-2)
        minutes = ('0' + dtm.getMinutes()).slice(-2)
        seconds = ('0' + dtm.getSeconds()).slice(-2)

        ymd = year + '/' + month + '/' + date
        ymdhms = ymd + ' ' + hours + ':' + minutes + ':' + seconds

        command = msg.rawCommand
        nick = msg.nick
        arg1 = msg.args[1] || ''

        # {{{ mysql log
        try
          #query = "insert into log (channel, command, nick, message) values ('#{channel}', '#{command}', '#{nick}', '#{arg1}');"
          query = "insert into log (channel, command, nick, message) values (?, ?, ?, ?);"
          #console.log query

          unless @client
            @client = mysql.createClient
              host: 'localhost'
              database: 'irc'
              user: 'irc'
              password: 'irc'

            @client.on 'error', (err) ->
              robot.emit 'error', err, msg

          @client.query query, [channel, command, nick, arg1], (err, results) =>
            if err
              msg.reply err
              return
            @client.query 'commit;'

#          @client.destroy()
        catch e
          console.log 'mysql error'
          console.log e
        # }}}

        # {{{ file log
        try
          #logContent = (JSON.stringify {
            #command: msg.rawCommand,
            #args: msg.args,
            #time: time,
            #nick: msg.nick
          #}) + ",\n"

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
        catch e
          console.log 'file error'
          console.log e
        # }}}

  robot.brain.on 'close', ->
    console.log 'close!'

# }}}

