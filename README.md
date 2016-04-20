# hubot-eavesdrop

A hubot script to perform actions when user-specified keywords are mentioned.

See [`src/eavesdrop.coffee`](src/eavesdrop.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-eavesdrop --save`

Then add **hubot-eavesdrop** to your `external-scripts.json`:

```json
["hubot-eavesdrop"]
```

## Sample Interaction

```
user1>> hubot when you hear slow clap do echo http://i.imgur.com/0mKXcg1.gif
user1>> slow clap
hubot>> http://i.imgur.com/0mKXcg1.gif
```
