# Desjcription:
#   LOG
#
# Commands:
#
# URLs:
#   GET /hubot/irclog
#
fs = require 'fs'
mkdirp = require 'mkdirp'
mysql = require 'mysql'
MeCab = require 'mecab-async'
DateUtil = require 'date-utils'
escape = require('validator').escape
#exec = require('child_process').exec
PATH_LOG_ROOT = process.env.HUBOT_LOG_ROOT
IRC_LOG_LIMIT = process.env.HUBOT_IRC_LOG_LIMIT

createMySqlClient = (robot) -># {{{
  unless @client
    console.log 'create mysql client!!!'
    @client = mysql.createClient
      host: 'localhost'
      database: 'irc'
      user: 'irc'
      password: 'irc'

    @client.on 'error', (err) ->
      robot.emit 'irc error', err, msg

  @client
# }}}

htmlContent = (robot, req, logs) -> # {{{
  text = escape req.query.text || ''
  channels = escape req.query.channels || ''
  nicknames = escape req.query.nicknames || ''

  # {{{ html head
  html = """
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!-- Latest compiled and minified CSS -->
    <!-- link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css" -->
    <!-- Optional theme -->
    <!-- link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap-theme.min.css" -->

    <!-- for handsontable { -->
    <link rel="stylesheet" href="https://v157-7-208-230.myvps.jp/javascripts/vendor/bootstrap.min.css">
    <link rel="stylesheet" href="https://v157-7-208-230.myvps.jp/javascripts/vendor/jquery.handsontable.full.css">
    <link rel="stylesheet" href="https://v157-7-208-230.myvps.jp/javascripts/vendor/jquery.handsontable.bootstrap.css">
    <style type="text/css">
      .localSearched {
        background: #ffcfaa;
        color: #583707;
      }
    </style>
    <!-- for handsontable } -->

    <!-- HTML5 Shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
    <script type="text/javascript">

      var data = 
  """
  #}}}

  # {{{ data
  # for item in logs
    #html += ('[' + "'#{item.id}', '#{(new Date item.event_time).toFormat('YY-MM-DD HH24:MI:SS')}', '#{item.channel}', '#{item.nick}', '#{item.message}'" + '],')
  items = ([item.id, (new Date item.event_time).toFormat('YY-MM-DD HH24:MI:SS'), item.channel, item.nick, item.message] for item in logs)
  html += JSON.stringify items
  # }}}

  #{{{ body top
  html += """
    ;
    </script>

    <title>HRS IRC log</title>
  </head>
  <body>
    <h1>HRS IRC log</h1>
    <div class="container">
    <div class="row">
      <form class="navbar-form navbar-left" role="search">
        <div class="form-group">
          <input type="text" name="text" class="form-control col-md-6" placeholder="Seach Text" value="#{text}">
          <!--button type="submit" id="doSearch" class="btn btn-default">検索</button-->
        </div>
      </form>
      <hr>
    </div> <!-- /.row -->
    </div> <!-- /.container -->

    <div style="padding-left: 20px">
      <input id="localSearch" type="search" placeholder="Local Search">
      <div class="pagination"><<< Newer - Older >>><ul id="gridPage"></ul></div>
      <div id="logsGrid" class="table table-striped table-bordered table-hover table-condensed">
  """
# dont use, becase use handsontable
#      <table id="logsGrid" class="table table-striped table-bordered table-hover table-condensed table-responsive">
#        <col class="col-xs-2">
#        <col class="col-xs-1">
#        <col class="col-xs-1">
#        <col class="col-xs-8">
#        <thead>
#          <th>日時</th><th>channel</th><th>nick</th><th>message</th>
#        </thead>
#        <tbody>
#
#  for item in logs
#    html += ('<tr><td><input type="hidden" value="' + item.id + '">' + (new Date item.event_time).toFormat('YY-MM-DD HH24:MI:SS') + '</td>' + '<td>' + item.channel + '</td>' + '<td>' + item.nick + '</td>' + '<td>' + item.message + '</td></tr>')
# }}}

# {{{ html bottom
#        </tbody>
#      </table>
  html += """
      </div> <!-- #logsGrid -->
    </div> <!-- /container -->

    <!--script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"></script-->
    <!-- Latest compiled and minified JavaScript -->
    <!--script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js"></script-->

    <!-- for handsontable { -->
    <script src="https://v157-7-208-230.myvps.jp/javascripts/vendor/jquery.min.js"></script>
    <script src="https://v157-7-208-230.myvps.jp/javascripts/vendor/jquery.handsontable.full.js"></script>
    <script src="https://v157-7-208-230.myvps.jp/javascripts/vendor/bootstrap.min.js"></script>
    <!-- for handsontable } -->

    <script type="text/javascript">
      var resizeTimeout
        , availableWidth
        , availableHeight
        , $window = $(window)
        , $logsGrid = $('#logsGrid')
        , $gridPage = $('#gridPage');

      var searchResult = function (instance, row, col, value, result) {
        Handsontable.Search.DEFAULT_CALLBACK.apply(this, arguments);
      };

      $(document).ready(function(){
        var calculateSize = function () {
          var offset = $logsGrid.offset();
          availableWidth = $window.width() - offset.left + $window.scrollLeft() - 20;
          availableHeight = $window.height() - offset.top + $window.scrollTop() - 20;
          $logsGrid.width(availableWidth).height(availableHeight);
        };
        $window.on('resize', calculateSize);

        var noOfRowstoShow = 20; //set the maximum number of rows that should be displayed per page.

        $logsGrid.handsontable({
          readOnly: true,
          width: ($window.width() - $logsGrid.offset().left + $window.scrollLeft() - 20),
          height: ($window.height() - $logsGrid.offset().top + $window.scrollTop() - 20),
          stretchH: 'all',
          colHeaders: true,
          colHeaders: ["DateTime", "Channel", "Nick", "Message"],
          columns: [
            {data: 1},
            {data: 2},
            {data: 3},
            {data: 4},
          ],
          currentRowClassName: 'active',
          currentColClassName: 'active',
          search: {
            searchResultClass: 'localSearched',
            callback: searchResult
          },
        });

        loadData();

        function loadData() {
          getgridData(data, "1", noOfRowstoShow);
        }

        //$('#localSearch').on('keyup', function (event) {
        //  var hot = $logsGrid.handsontable('getInstance');
        //  var queryResult = hot.search.query(this.value);
        //  console.log(queryResult);
        //  hot.render();
        //});

        // via. http://my-waking-dream.blogspot.jp/2013/12/live-search-filter-for-jquery.html
        $('#localSearch').on('keyup', function (event) {
          var value = ('' + this.value).toLowerCase(), row, col, r_len, c_len, td;
          var _data = data;
          var searcharray = [];
          if (value) {
            for (row = 0, r_len = data.length; row < r_len; row++) {
            //for (row = data.length - 1, r_len >= 0; row >= r_len; row--) {
              for (col = 0, c_len = _data[row].length; col < c_len; col++) {
                if (_data[row][col] == null) {
                  continue;
                }
                if (('' + _data[row][col]).toLowerCase().indexOf(value) > -1) {
                  searcharray.push(_data[row]);
                  break;
                } else {
                }
              }
            }
            getgridData(searcharray, "1", noOfRowstoShow);

          } else {
            getgridData(_data, "1", noOfRowstoShow);
          }
        });

        function getgridData(res, hash, noOfRowstoShow) {
          var page = parseInt(hash.replace('#', ''), 10) || 1, limit = noOfRowstoShow, row = (page - 1) * limit, count = page * limit, part = [];
          //for (; row < count; row++) {
          var minRow = row;
          row = count - 1;
          for (; row >= minRow; row--) {
            if (res[row] != null) {
              part.push(res[row]);
            }
          }

          var pages = Math.ceil(res.length / noOfRowstoShow);
          $gridPage.empty();
          for (var i = 1; i <= pages; i++) {
            var element = $('<li class="' + (i == page ? 'active' : '') + '"' + "><a href='#" + i + "'>" + i + "</a></li>");
            element.children('a').bind('click', function (e) {
              var hash = e.currentTarget.attributes[0].value;
              $logsGrid.handsontable('loadData', getgridData(res, hash, noOfRowstoShow));
            });
            $gridPage.append(element);
          }
          $logsGrid.handsontable('loadData', part);
          return part;
        }
      });
    </script>
  </body>
</html>
  """
# }}}
# }}}

getLogs = (robot, req, res) -> # {{{
  ret = []
  try
    @client = createMySqlClient robot

    query =   """
       select * from (select id, event_time, channel, nick, message from log
       where (command = 'PRIVMSG' or command = 'NOTICE')
       order by id desc limit #{IRC_LOG_LIMIT}) b
       order by b.id
    """

    # console.log query

    @client.query query, [], (err, results) =>
      if err
        console.log 'getLogs query error'
        console.log err

      # reverse
      ret.push item for item in results by -1

      res.end(htmlContent robot, req, ret)

  catch e
    console.log 'getLogs error'
    console.log e
    res.end(htmlContent robot, req, ret)
# }}}

module.exports = (robot) ->
  @client = null
  @mecab = null

  # {{{ log
  robot.adapter.bot.on 'raw', (msg) ->
    switch msg.rawCommand
      when 'NOTICE', 'PRIVMSG', 'PART', 'JOIN', 'TOPIC'
        # {{{ 初期設定
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
        message = msg.args[1] || ''
        # }}}

        # {{{ mecab
        try
          unless @mecab
            @mecab = new MeCab
            console.log 'create mecab!!!'
          replaced = message.replace /['\\]/g, (str, offset, s) ->
            ESCAPE = {
              "'": "'"
              "\\": "\\"
            }
            ESCAPE[str] + str
          replaced = "'" + replaced + "'"
          result = @mecab.parseSync replaced
          mecabstr = ""
          # console.lochannel:#{channel} nick:#{nick}g result
          for item in result when !(/(助詞|助動詞)/.test item[1].split("\t")[3])
            (sub = item[1].split("\t"); mecabstr += ' ' + item[0] + ' ' + sub[1] + ' ' + sub[2])
          # console.log mecabstr
        catch e
          console.log 'mecab error'
          console.log e
          throw e
        # }}}

        # {{{ mysql log
        try
          #query = "insert into log (channel, command, nick, message) values ('#{channel}', '#{command}', '#{nick}', '#{message}');"
          query = "insert into log (channel, command, nick, message, mecab) values (?, ?, ?, ?, ?);"
          #console.log query

          @client = createMySqlClient robot

          @client.query query, [channel, command, nick, message, mecabstr], (err, results) =>
            if err
              msg.reply err
              return

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

          logContent = "#{ymdhms}\t#{command}\t#{nick}\t#{message}\n"
          dir = "#{PATH_LOG_ROOT}/#{channel}"

          log = () ->
            #fs.appendFile "#{dir}/#{year}-#{month}-#{date}.log", logContent, console.log.bind console
            fs.appendFile "#{dir}/#{year}-#{month}-#{date}.log", logContent
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

  # }}}

  robot.router.get "/irclog", (req, res) -> # {{{
    res.setHeader 'content-type', 'text/html'
    getLogs robot, req, res
  # }}}

