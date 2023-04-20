/* page.js
 * Content script responsible for interacting with user's page.
 * Design & reasoning:
 * 1. Connection
 * a. content-page.js sends a connection request to background.js.
 * b. background.js will accept a connection only from content-page.js running in active tab.
 * c. Once background.js accepts a connection from content-page.js in active tab, any other 
 *    existing connection to content-page.js in inactive tab is closed.
**/
'use strict';


let $jQ  = jQuery.noConflict();
let port = null;  // Used to communicate with background/background.js

function showTranslation() {
  $jQ.widget("smart-translator.tooltip", {
    options: {
      terms: []
    },

    ttPos: $jQ.ui.tooltip.prototype.options.position,

    _create: function() {
      this._super();
      this._on({
        mouseup: this._tip,
        mouseenter: this._tip
      });
    },

    _destroy: function() {
      this._super();
      this._destroyTooltip();
    },

    _tip: function(e) {
      let text = this._selectedText();
      let term = this._selectedTerm(text);

      if (text === undefined || term === undefined) {
        this._destroyTooltip();
        return;
      }

      if (this.element.attr("title") !== term.tip) this._destroyTooltip();

      this._createTooltip(e, term);
    },

    _selectedText: function() {
      let selection = window.getSelection();

      if (selection.type !== "Range") return;

      let range = selection.getRangeAt(0),
      let fragment = $(range.cloneContents());

      return $.trim(fragment.text().toLowerCase());
    },

    _selectedTerm: function(text) {
      function isTerm(v) {
        if (v.term === text || v.term + "s" === text) return v;
      }
      return $.map(this.options.terms, isTerm)[0];
    },

    _createTooltip: function(e, term) {
      if (this.element.is(":ui-tooltip")) return;

      let pos = $.extend(this.ttPos, {of: e});

      this.element.attr("title", term.tip).tooltip({position: pos}).tooltip("open");
    },

    _destroyTooltip: function() {
      if (!this.element.is(":ui-tooltip")) return;

      this.element.tooltip("destroy").attr("title", "");
    }
  });

})( jQuery );

$(function() {

    var dict = [
        {
            term: "tooltip",
            tip: "A contextual widget providing information to the user"
        },
        {
            term: "progressbar",
            tip: "A widget illustrating the progress of some task"
        },
        {
            term: "element",
            tip: "An HTML element on the page"
        },
        {
            term: "user interface",
            tip: "Components on the screen the user interacts with"
        }
    ];

    $("p").dictionary({
        terms: dict
    });

});
}

function connectPort() {
  /* 1a. Connect to background.js.
   * 1b. Connection will be accepted only if content-page.js is running is active tab. */
  port = browser.runtime.connect({
    name: 'page'
  });
  console.debug('Connected content/page.js to background/background.js on Port:', port);

  /* 1c. Disconnect request will come from background.js when tab in which content/page.js is running
         becomes inactive. */
  port.onDisconnect.addListener((p) => {
    console.debug('Received request to disconnect Port:', p);
    if (p.error)
      console.error(`Port ${port.name} disconnected due to error: ${p.error.message}`);

    port = null;
  });
  console.debug('Registered onDisconnect() listener for Port:', port);

  /* Listen to messages sent from background.js */
  port.onMessage.addListener((message) => {
    console.debug('Received a message from background/background.js:', message);

    let selectionText = window.getSelection();
    console.debug(` selectionText:`, selectionText);

    let sourceText = document.createElement('span');
    sourceText.id  = 'smart-translator__text--source'; 
    // sourceText.title = message.translation;
    sourceText.textContent = selectionText.toString();
    /*
    let $sourceText = $('<span/>');
    $sourceText.attr('id', 'smart-translator__text--source');
    $sourceText.attr('title', message.translation);
    $sourceText.attr('textContent', selectionText.toString());
    */

    let translationText = document.createElement('span');
    translationText.id  = 'smart-translator__text--translation'; 
    translationText.textContent = message.targetText;
    //translationText.style.display = 'none';

    let range = selectionText.getRangeAt(0);
    range.deleteContents();
    range.insertNode(sourceText);

    $jQ('#smart-translator__text--translation').tooltip({
      show: {
        effect: 'blind',
        duration: 800
      },
      hide: {
        effect: 'blind',
        duration: 800
      },
    });
    console.debug('Range:', range);
  });
  console.debug('Registered onMessage() listener for Port:', port);

  return port;
}

function disconnectPort() {
  port.disconnect();
  port = null;

  console.debug('Disconnected content/page.js from background/background.js on Port:', port);
  return port;
}

$jQ(document).ready(() => {
  console.debug('document.ready()');

  $jQ(window).on('focus', (e) => {
    console.debug('event.type:', e.type, 'Port:', port);

    /* Active tab, connect to background.js */
    if (!port)
      connectPort();
    console.debug('Port:', port);

    if (port) {
      const msg = {
        time: `${date} ${new Date().toLocaleTimeString()}`,
        action: 'Test Page Port',
        text: 'Nothing here'
      };
      console.debug('Sending test message to background/background.js. Message:', msg, 'Port:', port);
      port.postMessage(msg);
      console.debug('Sent test message to background/background.js');
    }

    port;
  });
});
