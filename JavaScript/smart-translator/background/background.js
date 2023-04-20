/* background.js
 * Backround script responsible for relaying messages between page & translator. */
'use strict';

import {translateText} from '../translator/translate.js';

let ports = [];

/* SmartTranslator works with highlighted/selected text.
 * Keep conextMenus instead of menus for compatibility with other browsers. 
 * TO DO: Add locale specific menu.
 */
browser.runtime.onInstalled.addListener(() => {
  browser.contextMenus.create({
    "id": "smartTranslator",
    "title": "Smart Translation",
    "contexts": ["selection"]
  });
});

/* User chose to translate selected text */
browser.contextMenus.onClicked.addListener((info, tab) => {
  
  console.log('User clicked Smart Translation. Info:', info, 'Tab:', tab);

  /* TO DO: Add logic to not resubmit the same selection object */

  if (info.selectionText === undefined) {
    console.error('No text selected for translation');
    return false;
  }

  /* translateText() is async and therefore returns an implicity Promise */
  const params = {
    sourceLanguage: 'Auto-detect',
    targetLanguage: 'Polish'
  };
  translateText(info.selectionText, params)
  .then((result) => {
    console.debug(`typeof(result):${typeof(result)}`);
    console.debug(`Finished executing translateText(${info.selectionText}, ${JSON.stringify(params)}):`, result);
    /* Handle exception */
    result instanceof Error && console.error(`Error executing translateText(${info.selectionText}, ${JSON.stringify(params)}):`, result);
    /* Send translation to content/page.js */
    ports['page'] && ports['page'].postMessage(result);
  });
});

/* Received a request to open port for messaging */
browser.runtime.onConnect.addListener((port) => {

  /* Initialize port for content/page.js running in active tab only */
  if (port.name == 'page' && port.sender.tab.active == false)
    return false;

  /* Disconnect port for content/page.js running in tab which just changed from active to inactive */
  port.name == 'page' && ports[port.name] && ports[port.name].disconnect();

  ports[port.name] = port;

  console.debug('Received request to connect Port:', ports[port.name]);
  
  /* Listen to messages sent from content/page.js */
  ports[port.name].onMessage.addListener((message) => {
    console.debug(`Message from content script ${port.name}:`, message);
  });

  /* Close port upon disconnect request from the other end */
  ports[port.name].onDisconnect.addListener((p) => {
    console.debug('Received request to disconnect Port:', port);

    p.error && console.error(`Port ${port.name} disconnected due to error: ${p.error.message}`);

    ports[port.name] = null;
  });

  console.debug('Finished executing onConnect() for Port:', ports[port.name]);
});

