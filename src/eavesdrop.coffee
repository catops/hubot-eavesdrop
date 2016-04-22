# Description:
#   Have Hubot perform actions when it hears user-specified keywords.
#
# Dependencies:
#   quick-gist: 1.2.0
#
# Configuration:
#   HUBOT_EAVESDROP_DELAY: Seconds to wait before an event can be triggered a second time. Default is 30.
#
# Commands:
#   hubot when you hear <pattern> do <something hubot does> - Setup a eavesdropping event
#   hubot stop listening - Stop all eavesdropping (requires user to be an 'admin')
#   hubot stop listening for <pattern> - Remove a particular eavesdropping event
#   hubot show listening - Show what hubot is eavesdropping on
#
# Author:
#   garylin
#   contolini
#   inhumantsar

gist = require 'quick-gist'
TextMessage = require('hubot').TextMessage

class EavesDropping
  constructor: (@robot) ->
    @delay = process.env.HUBOT_EAVESDROP_DELAY || 30
    @recentEvents = {}

    eavesdroppings = @robot.brain.get 'eavesdroppings'
    @eavesdroppings = eavesdroppings or []
    @robot.brain.set 'eavesdroppings', @eavesdroppings
  add: (pattern, user, action, order) ->
    task = {key: pattern, task: action, order: order, creator: user}
    @eavesdroppings.push task
  all: -> @eavesdroppings
  deleteByPattern: (pattern, msg) ->
    filtered = @eavesdroppings.filter (n) -> n.key != pattern
    if @eavesdroppings.length == filtered.length
      return msg.send "I'm not listening for #{pattern}."
    @eavesdroppings = filtered
    @robot.brain.set 'eavesdroppings', @eavesdroppings
    msg.send "Okay, I will ignore #{pattern}."
  deleteAll: () ->
    @eavesdroppings = []
    @robot.brain.set 'eavesdroppings', @eavesdroppings

module.exports = (robot) ->
  eavesDropper = new EavesDropping robot

  robot.respond /when you hear (.+?) do (.+?)$/i, (msg) ->
    key = msg.match[1]
    for task_raw in msg.match[2].split ";"
      task_split = task_raw.split "|"
      # If it's a single task, don't add an "order" property
      if not task_split[1]
        eavesDropper.add(key, msg.envelope.user.name, task_split[0])
      else
        eavesDropper.add(key, msg.envelope.user.name, task_split[0], task_split[1])
    msg.send "I am now listening for #{key}."

  robot.respond /stop (listening|eavesdropping)$/i, (msg) ->
    if robot.auth.hasRole msg.envelope.user, 'admin'
      eavesDropper.deleteAll()
      msg.send 'Okay, I will no longer listen for anything.'
    else
      msg.send 'Sorry, only admins can delete all eavesdroppings.'

  robot.respond /stop (listening|eavesdropping) (for|on) (.+?)$/i, (msg) ->
    pattern = msg.match[3]
    eavesDropper.deleteByPattern(pattern, msg)

  robot.respond /show (listening|eavesdropping)s?/i, (msg) ->
    response = "\n"
    if eavesDropper.all().length < 1
      return msg.send "I'm not listening for anything."
    for task in eavesDropper.all()
      response += "#{task.key} -> #{task.task}\n"
    if response.length < 1000
      msg.send response
    else
      gist {content: response}, (err, resp, data) ->
        url = data.html_url
        msg.send "I'm listening for the following items: " + url

  robot.hear /(.+)/i, (msg) ->
    robotHeard = msg.match[1]

    tasks = eavesDropper.all()
    tasks.sort (a,b) ->
      return if a.order >= b.order then 1 else -1

    tasksToRun = []
    for task in tasks
      if new RegExp(task.key, "i").test(robotHeard)
        tasksToRun.push task

    tasksToRun.sort (a,b) ->
      return if a.order >= b.order then 1 else -1

    for task in tasksToRun
      if (robot.name != msg.message.user.name && !(new RegExp("^#{robot.name}", "i").test(robotHeard)))
        now = Date.now()
        lastTime = eavesDropper.recentEvents[task.key]
        if !lastTime or (now - lastTime) / 1000 > eavesDropper.delay
          robot.receive new TextMessage(msg.message.user, "#{robot.name}: #{task.task}")
        eavesDropper.recentEvents[task.key] = now
