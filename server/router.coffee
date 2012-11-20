# Functions for getting Controllers and Actions.
env = require('../config/environments/env')
paths = env.paths
routes = require(paths.entryPath + '/routes')

config = null;

# given a name, eg "listings#show"
# return function that matches that controller's action (eg the show method of the listings controller)
getAction = (config) ->
  controller = getController(config.controller);
  controller[config.action]

getController = (controllerName) ->
  require(paths.entryPath + "/controllers/#{controllerName}_controller")

getHandler = (action) ->
  (req, res, next) ->
    context =
      app: req.appContext
      redirectTo: (url) -> res.redirect(url)

    params = req.query || {}
    req.route.keys.forEach (routeKey) ->
      params[routeKey.name] = req.route.params[routeKey.name]

    start = new Date;
    action.call context, params, (err, template, data) ->
      if (config && config.stashPerf) 
        config.stashPerf(req, "data", new Date - start)
      return handleErr(err, req, res) if err
      start = new Date;
      res.render(template, locals: data, app: req.appContext, req: req)
      if (config && config.stashPerf) 
        config.stashPerf(req, "render", new Date - start)
        config.stashPerf(req, "afterRenderTotalTime")

handleErr = (err, req, res) ->
  if (config && config.stashError) 
    config.stashError(req, err)

  if err.statusCode && err.statusCode is 401
    res.redirect('/login')
  else
    if (env.name == 'development')
      throw err
    else
      res.render('error_view', app: req.appContext, req: req);

getAuthenticate = (routeInfo) ->
  (req, res, next) ->
    start = new Date;
    if routeInfo.authenticated && !req.appContext.loggedIn()
      res.redirect('/login')
    else
      config.stashPerf(req, "authenticate", new Date - start)
      next()

# config
# - stashError(req, err)
# - stashPerf(req, name, runtime)
exports.init = (conf) ->
  config = conf


# define routes
exports.routes = () ->
  routeSpecs = []
  for own path, routeInfo of routes
    action = getAction(routeInfo)
    handler = getHandler(action)
    authenticate = getAuthenticate(routeInfo)
    routeSpecs.push(['get', "/#{path}", authenticate, handler])

  routeSpecs
