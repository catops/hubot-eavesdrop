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
#   hubot when you hear <pattern> respond with <response> - Setup a eavesdropping event
#   hubot stop listening - Stop all eavesdropping (requires user to be an 'admin')
#   hubot stop listening for <pattern> - Remove a particular eavesdropping event
#   hubot show listening - Show what hubot is eavesdropping on
#
# Author:
#   garylin
#   contolini
#   inhumantsar

gist = require 'quick-gist'

class EavesDropping
  constructor: (@robot) ->
    @delay = process.env.HUBOT_EAVESDROP_DELAY || 30
    @recentEvents = {}
  add: (pattern, user, action, order) ->
    task = {key: pattern, task: action, order: order, creator: user}
    @eavesdroppings = @eavesdroppings or @robot.brain.get 'eavesdroppings'
    @eavesdroppings.push task
  all: ->
    @eavesdroppings or @robot.brain.get 'eavesdroppings'
  deleteByPattern: (pattern, msg) ->
    @eavesdroppings = @eavesdroppings or @robot.brain.get 'eavesdroppings'
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

  robot.respond /when you hear (.+?) do echo (.+?)$/i, (msg) ->
    msg.reply "Please use the new format: \"#{robot.name} when you hear [phrase] respond with [reponse]\""

  robot.respond /when you hear (.+?) (respond|reply) with (.+?)$/i, (msg) ->
    key = msg.match[1]
    for task_raw in msg.match[3].split ";"
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
      response += "#{task.key} -> #{task.task} (#{task.creator})\n"
    if response.length < 1000
      msg.send response
    else
      gist {content: response}, (err, resp, data) ->
        url = data.html_url
        msg.send "I'm listening for the following items: " + url

  robot.hear /(.+)/i, (msg) ->
    robotHeard = msg.match[1]

    # To play nicely with adapters that spoof the bot's name in DMs, don't respond
    # if the message starts with "hubot:" or "hubot when you hear"
    if new RegExp("^#{robot.name}\:", "i").test(robotHeard) or new RegExp("^(#{robot.name} )?when you hear", "i").test(robotHeard)
      return

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
      if robot.name != msg.message.user.name
        now = Date.now()
        lastTime = eavesDropper.recentEvents[task.key]
        if msg.message.user.name == task.creator or !lastTime or (now - lastTime) / 1000 > eavesDropper.delay
          robot.messageRoom msg.envelope.room, task.task
        eavesDropper.recentEvents[task.key] = now
