/** Initializes the LiveSocket
 *
 *
 * @param {string} endPoint - The string WebSocket endpoint, ie, `"wss://example.com/live"`,
 *                                               `"/live"` (inherited host & protocol)
 * @param {Phoenix.Socket} socket - the required Phoenix Socket class imported from "phoenix". For example:
 *
 *     import {Socket} from "phoenix"
 *     import {LiveSocket} from "phoenix_live_view"
 *     let liveSocket = new LiveSocket("/live", Socket, {...})
 *
 * @param {Object} [opts] - Optional configuration. Outside of keys listed below, all
 * configuration is passed directly to the Phoenix Socket constructor.
 * @param {Object} [opts.defaults] - The optional defaults to use for various bindings,
 * such as `phx-debounce`. Supports the following keys:
 *
 *   - debounce - the millisecond phx-debounce time. Defaults 300
 *   - throttle - the millisecond phx-throttle time. Defaults 300
 *
 * @param {Function} [opts.params] - The optional function for passing connect params.
 * The function receives the element associated with a given LiveView. For example:
 *
 *     (el) => {view: el.getAttribute("data-my-view-name", token: window.myToken}
 *
 * @param {string} [opts.bindingPrefix] - The optional prefix to use for all phx DOM annotations.
 * Defaults to "phx-".
 * @param {Object} [opts.hooks] - The optional object for referencing LiveView hook callbacks.
 * @param {Object} [opts.uploaders] - The optional object for referencing LiveView uploader callbacks.
 * @param {integer} [opts.loaderTimeout] - The optional delay in milliseconds to wait before apply
 * loading states.
 * @param {Function} [opts.viewLogger] - The optional function to log debug information. For example:
 *
 *     (view, kind, msg, obj) => console.log(`${view.id} ${kind}: ${msg} - `, obj)
 *
 * @param {Object} [opts.metadata] - The optional object mapping event names to functions for
 * populating event metadata. For example:
 *
 *     metadata: {
 *       click: (e, el) => {
 *         return {
 *           ctrlKey: e.ctrlKey,
 *           metaKey: e.metaKey,
 *           detail: e.detail || 1,
 *         }
 *       },
 *       keydown: (e, el) => {
 *         return {
 *           key: e.key,
 *           ctrlKey: e.ctrlKey,
 *           metaKey: e.metaKey,
 *           shiftKey: e.shiftKey
 *         }
 *       }
 *     }
 * @param {Object} [opts.sessionStorage] - An optional Storage compatible object
 * Useful when LiveView won't have access to `sessionStorage`.  For example, This could
 * happen if a site loads a cross-domain LiveView in an iframe.  Example usage:
 *
 *     class InMemoryStorage {
 *       constructor() { this.storage = {} }
 *       getItem(keyName) { return this.storage[keyName] }
 *       removeItem(keyName) { delete this.storage[keyName] }
 *       setItem(keyName, keyValue) { this.storage[keyName] = keyValue }
 *     }
 *
 * @param {Object} [opts.localStorage] - An optional Storage compatible object
 * Useful for when LiveView won't have access to `localStorage`.
 * See `opts.sessionStorage` for examples.
*/

import {
  BINDING_PREFIX,
  CONSECUTIVE_RELOADS,
  DEFAULTS,
  FAILSAFE_JITTER,
  LOADER_TIMEOUT,
  MAX_RELOADS,
  PHX_DEBOUNCE,
  PHX_DROP_TARGET,
  PHX_HAS_FOCUSED,
  PHX_KEY,
  PHX_LINK_STATE,
  PHX_LIVE_LINK,
  PHX_LV_DEBUG,
  PHX_LV_LATENCY_SIM,
  PHX_LV_PROFILE,
  PHX_MAIN,
  PHX_PARENT_ID,
  PHX_VIEW_SELECTOR,
  PHX_ROOT_ID,
  PHX_THROTTLE,
  PHX_TRACK_UPLOADS,
  RELOAD_JITTER

} from "./constants"

import {
  clone,
  closestPhxBinding,
  closure,
  debug,
  maybe
} from "./utils"

import Browser from "./browser"
import DOM from "./dom"
import Hooks from "./hooks"
import LiveUploader from "./live_uploader"
import View from "./view"
import {PHX_SESSION} from "./constants"

export default class LiveSocket {
  constructor(url, phxSocket, opts = {}){
    this.unloaded = false
    if(!phxSocket || phxSocket.constructor.name === "Object"){
      throw new Error(`
      a phoenix Socket must be provided as the second argument to the LiveSocket constructor. For example:

          import {Socket} from "phoenix"
          import LiveSocket from "phoenix_live_view"
          let liveSocket = new LiveSocket("/live", Socket, {...})
      `)
    }
    this.socket = new phxSocket(url, opts)
    this.bindingPrefix = opts.bindingPrefix || BINDING_PREFIX
    this.opts = opts
    this.params = closure(opts.params || {})
    this.viewLogger = opts.viewLogger
    this.metadataCallbacks = opts.metadata || {}
    this.defaults = Object.assign(clone(DEFAULTS), opts.defaults || {})
    this.activeElement = null
    this.prevActive = null
    this.silenced = false
    this.main = null
    this.linkRef = 1
    this.roots = {}
    this.href = window.location.href
    this.pendingLink = null
    this.currentLocation = clone(window.location)
    this.hooks = opts.hooks || {}
    this.uploaders = opts.uploaders || {}
    this.loaderTimeout = opts.loaderTimeout || LOADER_TIMEOUT
    this.localStorage = opts.localStorage || window.localStorage
    this.sessionStorage = opts.sessionStorage || window.sessionStorage
    this.boundTopLevelEvents = false
    this.domCallbacks = Object.assign({onNodeAdded: closure(), onBeforeElUpdated: closure()}, opts.dom || {})
    window.addEventListener("pagehide", _e => {
      this.unloaded = true
    })
    this.socket.onOpen(() => {
      if(this.isUnloaded()){
        // reload page if being restored from back/forward cache and browser does not emit "pageshow"
        window.location.reload()
      }
    })
  }

  // public

  isProfileEnabled(){ return this.sessionStorage.getItem(PHX_LV_PROFILE) === "true" }

  isDebugEnabled(){ return this.sessionStorage.getItem(PHX_LV_DEBUG) === "true" }

  enableDebug(){ this.sessionStorage.setItem(PHX_LV_DEBUG, "true") }

  enableProfiling(){ this.sessionStorage.setItem(PHX_LV_PROFILE, "true") }

  disableDebug(){ this.sessionStorage.removeItem(PHX_LV_DEBUG) }

  disableProfiling(){ this.sessionStorage.removeItem(PHX_LV_PROFILE) }

  enableLatencySim(upperBoundMs){
    this.enableDebug()
    console.log("latency simulator enabled for the duration of this browser session. Call disableLatencySim() to disable")
    this.sessionStorage.setItem(PHX_LV_LATENCY_SIM, upperBoundMs)
  }

  disableLatencySim(){ this.sessionStorage.removeItem(PHX_LV_LATENCY_SIM) }

  getLatencySim(){
    let str = this.sessionStorage.getItem(PHX_LV_LATENCY_SIM)
    return str ? parseInt(str) : null
  }

  getSocket(){ return this.socket }

  connect(){
    let doConnect = () => {
      if(this.joinRootViews()){
        this.bindTopLevelEvents()
        this.socket.connect()
      }
    }
    if(["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0){
      doConnect()
    } else {
      document.addEventListener("DOMContentLoaded", () => doConnect())
    }
  }

  disconnect(callback){ this.socket.disconnect(callback) }

  // private

  triggerDOM(kind, args){ this.domCallbacks[kind](...args) }

  time(name, func){
    if(!this.isProfileEnabled() || !console.time){ return func() }
    console.time(name)
    let result = func()
    console.timeEnd(name)
    return result
  }

  log(view, kind, msgCallback){
    if(this.viewLogger){
      let [msg, obj] = msgCallback()
      this.viewLogger(view, kind, msg, obj)
    } else if(this.isDebugEnabled()){
      let [msg, obj] = msgCallback()
      debug(view, kind, msg, obj)
    }
  }

  onChannel(channel, event, cb){
    channel.on(event, data => {
      let latency = this.getLatencySim()
      if(!latency){
        cb(data)
      } else {
        console.log(`simulating ${latency}ms of latency from server to client`)
        setTimeout(() => cb(data), latency)
      }
    })
  }

  wrapPush(view, opts, push){
    let latency = this.getLatencySim()
    let oldJoinCount = view.joinCount
    if(!latency){
      if(opts.timeout){
        return push().receive("timeout", () => {
          if(view.joinCount === oldJoinCount && !view.isDestroyed()){
            this.reloadWithJitter(view, () => {
              this.log(view, "timeout", () => ["received timeout while communicating with server. Falling back to hard refresh for recovery"])
            })
          }
        })
      } else {
        return push()
      }
    }

    console.log(`simulating ${latency}ms of latency from client to server`)
    let fakePush = {
      receives: [],
      receive(kind, cb){ this.receives.push([kind, cb]) }
    }
    setTimeout(() => {
      if(view.isDestroyed()){ return }
      fakePush.receives.reduce((acc, [kind, cb]) => acc.receive(kind, cb), push())
    }, latency)
    return fakePush
  }

  reloadWithJitter(view, log){
    view.destroy()
    this.disconnect()
    let [minMs, maxMs] = RELOAD_JITTER
    let afterMs = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs
    let tries = Browser.updateLocal(this.localStorage, window.location.pathname, CONSECUTIVE_RELOADS, 0, count => count + 1)
    log ? log() : this.log(view, "join", () => [`encountered ${tries} consecutive reloads`])
    if(tries > MAX_RELOADS){
      this.log(view, "join", () => [`exceeded ${MAX_RELOADS} consecutive reloads. Entering failsafe mode`])
      afterMs = FAILSAFE_JITTER
    }
    setTimeout(() => {
      if(this.hasPendingLink()){
        window.location = this.pendingLink
      } else {
        window.location.reload()
      }
    }, afterMs)
  }

  getHookCallbacks(name){
    return name && name.startsWith("Phoenix.") ? Hooks[name.split(".")[1]] : this.hooks[name]
  }

  isUnloaded(){ return this.unloaded }

  isConnected(){ return this.socket.isConnected() }

  getBindingPrefix(){ return this.bindingPrefix }

  binding(kind){ return `${this.getBindingPrefix()}${kind}` }

  channel(topic, params){ return this.socket.channel(topic, params) }

  joinRootViews(){
    let rootsFound = false
    DOM.all(document, `${PHX_VIEW_SELECTOR}:not([${PHX_PARENT_ID}])`, rootEl => {
      if(!this.getRootById(rootEl.id)){
        let view = this.newRootView(rootEl)
        view.setHref(this.getHref())
        view.join()
        if(rootEl.getAttribute(PHX_MAIN)){ this.main = view }
      }
      rootsFound = true
    })
    return rootsFound
  }

  redirect(to, flash){
    this.disconnect()
    Browser.redirect(to, flash)
  }

  replaceMain(href, flash, callback = null, linkRef = this.setPendingLink(href)){
    let oldMainEl = this.main.el
    let newMainEl = DOM.cloneNode(oldMainEl, "")
    this.main.showLoader(this.loaderTimeout)
    this.main.destroy()

    this.main = this.newRootView(newMainEl, flash)
    this.main.setRedirect(href)
    this.main.join(joinCount => {
      if(joinCount === 1 && this.commitPendingLink(linkRef)){
        oldMainEl.replaceWith(newMainEl)
        callback && callback()
      }
    })
  }

  isPhxView(el){ return el.getAttribute && el.getAttribute(PHX_SESSION) !== null }

  newRootView(el, flash){
    let view = new View(el, this, null, flash)
    this.roots[view.id] = view
    return view
  }

  owner(childEl, callback){
    let view = maybe(childEl.closest(PHX_VIEW_SELECTOR), el => this.getViewByEl(el))
    if(view){ callback(view) }
  }

  withinOwners(childEl, callback){
    this.owner(childEl, view => {
      let phxTarget = childEl.getAttribute(this.binding("target"))
      if(phxTarget === null){
        callback(view, childEl)
      } else {
        view.withinTargets(phxTarget, callback)
      }
    })
  }

  getViewByEl(el){
    let rootId = el.getAttribute(PHX_ROOT_ID)
    return maybe(this.getRootById(rootId), root => root.getDescendentByEl(el))
  }

  getRootById(id){ return this.roots[id] }

  destroyAllViews(){
    for(let id in this.roots){
      this.roots[id].destroy()
      delete this.roots[id]
    }
  }

  destroyViewByEl(el){
    let root = this.getRootById(el.getAttribute(PHX_ROOT_ID))
    if(root){ root.destroyDescendent(el.id) }
  }

  setActiveElement(target){
    if(this.activeElement === target){ return }
    this.activeElement = target
    let cancel = () => {
      if(target === this.activeElement){ this.activeElement = null }
      target.removeEventListener("mouseup", this)
      target.removeEventListener("touchend", this)
    }
    target.addEventListener("mouseup", cancel)
    target.addEventListener("touchend", cancel)
  }

  getActiveElement(){
    if(document.activeElement === document.body){
      return this.activeElement || document.activeElement
    } else {
      // document.activeElement can be null in Internet Explorer 11
      return document.activeElement || document.body
    }
  }

  dropActiveElement(view){
    if(this.prevActive && view.ownsElement(this.prevActive)){
      this.prevActive = null
    }
  }

  restorePreviouslyActiveFocus(){
    if(this.prevActive && this.prevActive !== document.body){
      this.prevActive.focus()
    }
  }

  blurActiveElement(){
    this.prevActive = this.getActiveElement()
    if(this.prevActive !== document.body){ this.prevActive.blur() }
  }

  bindTopLevelEvents(){
    if(this.boundTopLevelEvents){ return }

    this.boundTopLevelEvents = true
    document.body.addEventListener("click", function (){ }) // ensure all click events bubble for mobile Safari
    window.addEventListener("pageshow", e => {
      if(e.persisted){ // reload page if being restored from back/forward cache
        this.getSocket().disconnect()
        this.withPageLoading({to: window.location.href, kind: "redirect"})
        window.location.reload()
      }
    }, true)
    this.bindNav()
    this.bindClicks()
    this.bindForms()
    this.bind({keyup: "keyup", keydown: "keydown"}, (e, type, view, target, targetCtx, phxEvent, _phxTarget) => {
      let matchKey = target.getAttribute(this.binding(PHX_KEY))
      let pressedKey = e.key && e.key.toLowerCase() // chrome clicked autocompletes send a keydown without key
      if(matchKey && matchKey.toLowerCase() !== pressedKey){ return }

      view.pushKey(target, targetCtx, type, phxEvent, {key: e.key, ...this.eventMeta(type, e, target)})
    })
    this.bind({blur: "focusout", focus: "focusin"}, (e, type, view, targetEl, targetCtx, phxEvent, phxTarget) => {
      if(!phxTarget){
        view.pushEvent(type, targetEl, targetCtx, phxEvent, this.eventMeta(type, e, targetEl))
      }
    })
    this.bind({blur: "blur", focus: "focus"}, (e, type, view, targetEl, targetCtx, phxEvent, phxTarget) => {
      // blur and focus are triggered on document and window. Discard one to avoid dups
      if(phxTarget && !phxTarget !== "window"){
        view.pushEvent(type, targetEl, targetCtx, phxEvent, this.eventMeta(type, e, targetEl))
      }
    })
    window.addEventListener("dragover", e => e.preventDefault())
    window.addEventListener("drop", e => {
      e.preventDefault()
      let dropTargetId = maybe(closestPhxBinding(e.target, this.binding(PHX_DROP_TARGET)), trueTarget => {
        return trueTarget.getAttribute(this.binding(PHX_DROP_TARGET))
      })
      let dropTarget = dropTargetId && document.getElementById(dropTargetId)
      let files = Array.from(e.dataTransfer.files || [])
      if(!dropTarget || dropTarget.disabled || files.length === 0 || !(dropTarget.files instanceof FileList)){ return }

      LiveUploader.trackFiles(dropTarget, files)
      dropTarget.dispatchEvent(new Event("input", {bubbles: true}))
    })
    this.on(PHX_TRACK_UPLOADS, e => {
      let uploadTarget = e.target
      if(!DOM.isUploadInput(uploadTarget)){ return }
      let files = Array.from(e.detail.files || []).filter(f => f instanceof File || f instanceof Blob)
      LiveUploader.trackFiles(uploadTarget, files)
      uploadTarget.dispatchEvent(new Event("input", {bubbles: true}))
    })
  }

  eventMeta(eventName, e, targetEl){
    let callback = this.metadataCallbacks[eventName]
    return callback ? callback(e, targetEl) : {}
  }

  setPendingLink(href){
    this.linkRef++
    this.pendingLink = href
    return this.linkRef
  }

  commitPendingLink(linkRef){
    if(this.linkRef !== linkRef){
      return false
    } else {
      this.href = this.pendingLink
      this.pendingLink = null
      return true
    }
  }

  getHref(){ return this.href }

  hasPendingLink(){ return !!this.pendingLink }

  bind(events, callback){
    for(let event in events){
      let browserEventName = events[event]

      this.on(browserEventName, e => {
        let binding = this.binding(event)
        let windowBinding = this.binding(`window-${event}`)
        let targetPhxEvent = e.target.getAttribute && e.target.getAttribute(binding)
        if(targetPhxEvent){
          this.debounce(e.target, e, () => {
            this.withinOwners(e.target, (view, targetCtx) => {
              callback(e, event, view, e.target, targetCtx, targetPhxEvent, null)
            })
          })
        } else {
          DOM.all(document, `[${windowBinding}]`, el => {
            let phxEvent = el.getAttribute(windowBinding)
            this.debounce(el, e, () => {
              this.withinOwners(el, (view, targetCtx) => {
                callback(e, event, view, el, targetCtx, phxEvent, "window")
              })
            })
          })
        }
      })
    }
  }

  bindClicks(){
    this.bindClick("click", "click", false)
    this.bindClick("mousedown", "capture-click", true)
  }

  bindClick(eventName, bindingName, capture){
    let click = this.binding(bindingName)
    window.addEventListener(eventName, e => {
      if(!this.isConnected()){ return }
      let target = null
      if(capture){
        target = e.target.matches(`[${click}]`) ? e.target : e.target.querySelector(`[${click}]`)
      } else {
        target = closestPhxBinding(e.target, click)
      }
      let phxEvent = target && target.getAttribute(click)
      if(!phxEvent){ return }
      if(target.getAttribute("href") === "#"){ e.preventDefault() }

      this.debounce(target, e, () => {
        this.withinOwners(target, (view, targetCtx) => {
          view.pushEvent("click", target, targetCtx, phxEvent, this.eventMeta("click", e, target))
        })
      })
    }, capture)
  }

  bindNav(){
    if(!Browser.canPushState()){ return }
    if(history.scrollRestoration){ history.scrollRestoration = "manual" }
    let scrollTimer = null
    window.addEventListener("scroll", _e => {
      clearTimeout(scrollTimer)
      scrollTimer = setTimeout(() => {
        Browser.updateCurrentState(state => Object.assign(state, {scroll: window.scrollY}))
      }, 100)
    })
    window.addEventListener("popstate", event => {
      if(!this.registerNewLocation(window.location)){ return }
      let {type, id, root, scroll} = event.state || {}
      let href = window.location.href

      if(this.main.isConnected() && (type === "patch" && id === this.main.id)){
        this.main.pushLinkPatch(href, null)
      } else {
        this.replaceMain(href, null, () => {
          if(root){ this.replaceRootHistory() }
          if(typeof(scroll) === "number"){
            setTimeout(() => {
              window.scrollTo(0, scroll)
            }, 0) // the body needs to render before we scroll.
          }
        })
      }
    }, false)
    window.addEventListener("click", e => {
      let target = closestPhxBinding(e.target, PHX_LIVE_LINK)
      let type = target && target.getAttribute(PHX_LIVE_LINK)
      let wantsNewTab = e.metaKey || e.ctrlKey || e.button === 1
      if(!type || !this.isConnected() || !this.main || wantsNewTab){ return }
      let href = target.href
      let linkState = target.getAttribute(PHX_LINK_STATE)
      e.preventDefault()
      if(this.pendingLink === href){ return }

      if(type === "patch"){
        this.pushHistoryPatch(href, linkState, target)
      } else if(type === "redirect"){
        this.historyRedirect(href, linkState)
      } else {
        throw new Error(`expected ${PHX_LIVE_LINK} to be "patch" or "redirect", got: ${type}`)
      }
    }, false)
  }

  withPageLoading(info, callback){
    DOM.dispatchEvent(window, "phx:page-loading-start", info)
    let done = () => DOM.dispatchEvent(window, "phx:page-loading-stop", info)
    return callback ? callback(done) : done
  }

  pushHistoryPatch(href, linkState, targetEl){
    this.withPageLoading({to: href, kind: "patch"}, done => {
      this.main.pushLinkPatch(href, targetEl, linkRef => {
        this.historyPatch(href, linkState, linkRef)
        done()
      })
    })
  }

  historyPatch(href, linkState, linkRef = this.setPendingLink(href)){
    if(!this.commitPendingLink(linkRef)){ return }

    Browser.pushState(linkState, {type: "patch", id: this.main.id}, href)
    this.registerNewLocation(window.location)
  }

  historyRedirect(href, linkState, flash){
    let scroll = window.scrollY
    this.withPageLoading({to: href, kind: "redirect"}, done => {
      this.replaceMain(href, flash, () => {
        Browser.pushState(linkState, {type: "redirect", id: this.main.id, scroll: scroll}, href)
        this.registerNewLocation(window.location)
        done()
      })
    })
  }

  replaceRootHistory(){
    Browser.pushState("replace", {root: true, type: "patch", id: this.main.id})
  }

  registerNewLocation(newLocation){
    let {pathname, search} = this.currentLocation
    if(pathname + search === newLocation.pathname + newLocation.search){
      return false
    } else {
      this.currentLocation = clone(newLocation)
      return true
    }
  }

  bindForms(){
    let iterations = 0
    this.on("submit", e => {
      let phxEvent = e.target.getAttribute(this.binding("submit"))
      if(!phxEvent){ return }
      e.preventDefault()
      e.target.disabled = true
      this.withinOwners(e.target, (view, targetCtx) => view.submitForm(e.target, targetCtx, phxEvent))
    }, false)

    for(let type of ["change", "input"]){
      this.on(type, e => {
        let input = e.target
        let phxEvent = input.form && input.form.getAttribute(this.binding("change"))
        if(!phxEvent){ return }
        if(input.type === "number" && input.validity && input.validity.badInput){ return }
        let currentIterations = iterations
        iterations++
        let {at: at, type: lastType} = DOM.private(input, "prev-iteration") || {}
        // detect dup because some browsers dispatch both "input" and "change"
        if(at === currentIterations - 1 && type !== lastType){ return }

        DOM.putPrivate(input, "prev-iteration", {at: currentIterations, type: type})

        this.debounce(input, e, () => {
          this.withinOwners(input.form, (view, targetCtx) => {
            DOM.putPrivate(input, PHX_HAS_FOCUSED, true)
            if(!DOM.isTextualInput(input)){
              this.setActiveElement(input)
            }
            view.pushInput(input, targetCtx, null, phxEvent, e.target)
          })
        })
      }, false)
    }
  }

  debounce(el, event, callback){
    let phxDebounce = this.binding(PHX_DEBOUNCE)
    let phxThrottle = this.binding(PHX_THROTTLE)
    let defaultDebounce = this.defaults.debounce.toString()
    let defaultThrottle = this.defaults.throttle.toString()
    DOM.debounce(el, event, phxDebounce, defaultDebounce, phxThrottle, defaultThrottle, callback)
  }

  silenceEvents(callback){
    this.silenced = true
    callback()
    this.silenced = false
  }

  on(event, callback){
    window.addEventListener(event, e => {
      if(!this.silenced){ callback(e) }
    })
  }
}
