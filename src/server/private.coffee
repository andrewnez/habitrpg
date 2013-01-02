module.exports.middleware = (req, res, next) ->
  model = req.getModel()
  model.set '_stripePubKey', process.env.STRIPE_PUB_KEY
  return next()

module.exports.app = (appExports, model) ->

  ###
    Buy Reroll Button
  ###
  appExports.buyReroll = (e, el, next) ->
    user = model.at('_user')
    user.set('balance', user.get('balance')-1)
    for taskId of user.get('tasks')
      task = model.at('_user.tasks.'+taskId)
      task.set('value', 0) unless task.get('type')=='reward'

  ###
    Initialize Stripe
  ###
  Stripe.setPublishableKey model.get('_stripePubKey')

  appExports.submitPayment = (e) ->

    # this identifies your website in the createToken call below
    stripeResponseHandler = (status, response) ->
      console.log {status:status, response:response}
      if response.error
        # re-enable the submit button
        $(".submit-button").removeAttr "disabled"
        # show the errors on the form
        $(".payment-errors").html "<span class='alert alert-error'>" + response.error.message + "</span>";
      else
        form$ = $("#payment-form")
        # token contains id, last4, and card type
        token = response["id"]
        # insert the token into the form so it gets submitted to the server
        form$.append "<input type='hidden' name='stripeToken' value='" + token + "' />"
        # and submit
        form$.get(0).submit()
      # disable the submit button to prevent repeated clicks
      $(".submit-button").attr "disabled", "disabled"

    # createToken returns immediately - the supplied callback submits the form if there are no errors
    Stripe.createToken
      number: $(".card-number").val()
      cvc: $(".card-cvc").val()
      exp_month: $(".card-expiry-month").val()
      exp_year: $(".card-expiry-year").val()
    , stripeResponseHandler
# return false # prevent the form from submitting with the default action


module.exports.routes = (expressApp) ->
  ###
    Setup Stripe response when posting payment
  ###
  expressApp.post '/', (req) ->
    stripeCallback = (err, response) ->
      if err
        console.error(err, 'Stripe Error')
        throw err
      else
        model = req.getModel()
        userId = model.session.userId
        model.fetch "users.#{userId}", (err, user) ->
          model.ref '_user', "users.#{userId}"
          model.set('_user.balance', model.get('_user.balance')+5)
          req.res.redirect('/')

    api_key = process.env.STRIPE_API_KEY # secret stripe API key
    stripe = require("stripe")(api_key)
    token = req.param('stripeToken', null)
    # console.dir {token:token, req:req}, 'stripe'
    stripe.charges.create
      amount: "500" # $5
      currency: "usd"
      card: token
    , stripeCallback