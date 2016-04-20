chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'eavesdrop', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()
      brain: 
        get: sinon.spy()
        set: sinon.spy()

    require('../src/eavesdrop')(@robot)

  it 'registers a respond listener', ->
    expect(@robot.respond).to.have.been.calledWith(/when you hear (.+?) do (.+?)$/i)

  it 'registers a hear listener', ->
    expect(@robot.hear).to.have.been.calledWith(/(.+)/i)
