/* translate.js
 * This module allows translation of text */
'use strict';

import {languageCode, getCodeForLanguage, getLanguageForCode, isSupported} from '../utils/languages.js';


/* Get sourceText definitions
 *
 * @param {Object} data
 * Object returned from https://translate.googleapis.com/translate_a/single?client=gtx
 *
 * @returns {Object|null}
 * Definitions and examples for sourceText, organized by part of speach */
function getSourceTextDefinitions(data) {
  if (!('definitions' in data)) return null; 
  if (!(data.definitions instanceof Array)) return null;

  let definitions = {};
  data.definitions.forEach((part_of_speach) => {
    /* part_of_speach = {noun|verb|adjective|adverb} */
    definitions[part_of_speach.pos] = [];
    part_of_speach.entry.forEach((definition) => {
      definitions[part_of_speach.pos].push({
        'base_form': part_of_speach.base_form,  // string
        'definition': definition.gloss,         // string
        'example': definition.example           // string
      });
    });
  });
  console.debug('getSourceTextDefinitions(data):', definitions);

  return Object.keys(definitions).length ? definitions : null;
}

/* Get sourceText synonyms
 *
 * @param {Object} data
 * Object returned from https://translate.googleapis.com/translate_a/single?client=gtx
 *
 * @returns {Object|null}
 * Synonyms for sourceText, organized by part of speach */
function getSourceTextSynonyms(data) {
  if (!('synsets' in data)) return null; 
  if (!(data.synsets instanceof Array)) return null;

  let synonyms = {};
  data.synsets.forEach((part_of_speach) => {
    /* part_of_speach = {noun|verb|adjective|adverb} */
    synonyms[part_of_speach.pos] = [];
    part_of_speach.entry.forEach((synonym) => {
      synonyms[part_of_speach.pos].push({
        'base_form': part_of_speach.base_form,  // string
        'synonyms': synonym.synonym             // [string,string,string]
      });
    });
  });
  console.debug('getSourceTextSynonyms(data):', synonyms);

  return Object.keys(synonyms).length ? synonyms : null;
}

/* Get targetText translation
 *
 * @param {Object} data
 * Object returned from https://translate.googleapis.com/translate_a/single?client=gtx
 *
 * @returns {string|null}
 * Translation text for sourceText */
function getTargetText(data) {
  if (!('sentences' in data)) return null; 
  if (!(data.sentences instanceof Array)) return null;

  let targetText = '';
  data.sentences.forEach((sentence) => {
    if ('trans' in sentence)
      targetText = targetText + sentence.trans;
  });
  console.debug('getTargetText(data):', targetText);

  return targetText || null;
}

/* Get targetText synonyms
 *
 * @param {Object} data
 * Object returned from https://translate.googleapis.com/translate_a/single?client=gtx
 *
 * @returns {Object|null}
 * Synonyms for targetText, organized by part of speach */
function getTargetTextSynonyms(data) {
  if (!('dict' in data)) return null; 
  if (!(data.dict instanceof Array)) return null;

  let synonyms = {};
  data.dict.forEach((part_of_speach) => {
    /* part_of_speach = {noun|verb|adjective|adverb} */
    synonyms[part_of_speach.pos] = {
      'base_form': part_of_speach.base_form,  // string
      'synonyms': part_of_speach.terms        // [string,string,string]
    };
  });
  console.debug('getTargetTextSynonyms(data):', synonyms);

  return Object.keys(synonyms).length ? synonyms : null;
}

/* Translate text using Google Translate internal API (translate.googleapis.com)
 *
 * @param {string} sourceText
 *
 * @param {Object} params 
 *
 * @returns {Object}
 * Translation object consisting of: sourceLanguage, sourceText, sourceTextSynonyms,
 * sourceTextDefinitions, targetLanguage, targetText, targetTextSynonyms
 * Or 
 * Error object if any issues are encountered */
async function getAPITranslation(sourceText, params) {
  let translateURL = 'https://translate.googleapis.com/translate_a/single?client=gtx';
  let pronounceURL = 'https://translate.googleapis.com/translate_tts?client=tw-ob';

  try {
    /* @param {string) sl - Source Language */
    translateURL = translateURL + '&sl=' + getCodeForLanguage(params.sourceLanguage);
  
    /* @param {string} tl - Target Language */
    translateURL = translateURL + '&tl=' + getCodeForLanguage(params.targetLanguage);
  
    /* @param {string} dt
     *
     * @value {string} at
     * @returns [{...}] alternative_translations
     * Array of Object(s) where an object contains an alternative translation of sourceText
     * In google translate page this shows when clicked on translated word
     * 
     * @value {string} bd
     * @returns [{...},...,{...}] dict
     * Full translate with synonym. Array of Object(s) where an object contains a form (verb, noun,
     * adjective) of the source text. Applies only to single word text & sl=en
     * 
     * @value {string} ex
     * @returns {[{...},...,{...}]} examples
     * Object containing usage examples of the source text. Applies only to single word text & sl=en
     * 
     * @value {string} ld 
     * @returns {} ld_result
     * Object containing sourceLanguage and confidence of detection of such language
     * 
     * @value {string} md
     * @returns [{...},...,{...}] definitions
     * Array of Object(s) where an object contains a definition of source text and its usage
     * Applies only to text that has a definition & sl=en
     * 
     * @value {string} qca
     * @returns ?
     * No idea what it represents
     * 
     * @value {string} rw
     * @returns {} related_words
     * Object with Array of related words. Applies only to single word text & sl=en
     * Eg. "broadcasting" => {["broadcast"]}
     * 
     * @value {string} rm
     * @returns {} ?
     * 
     * @value {string} ss
     * @returns [{...},...,{...}] synsets 
     * Array of Object(s) of synonyms. Applies only to single word text & sl=en
     * 
     * @value {string} t
     * @returns [{...},...,{...}] sentences 
     * Array of Objects containing original text and translation. Short sourceText is packed into
     * one object, long sourceText is split up into multiple objects */
    ['at', 'bd', 'ex', 'ld', 'md', 'qca', 'rw', 'rm', 'ss', 't'].forEach((value) => {
      translateURL = translateURL + '&dt=' + value;
    });

    /* @param {string} dj - Adds labels to data objects allowing for access by name */
    translateURL = translateURL + '&dj=1';
  
    /* @param {string} q - Query */
    translateURL = translateURL + '&q=' + encodeURIComponent(sourceText);
    pronounceURL = pronounceURL + '&ie=UTF-8&total=1&idx=0&tl=en' + '&q=' + encodeURIComponent(sourceText);

    /* Get translation */
    const response = await fetch(translateURL, {
      method: 'GET',
      mode: 'cors'
    });
    console.debug(`Successfully executed fetch(${translateURL}, {method:'GET',mode:'cors'}):`, response);
  
    const data = await response.json();
    console.debug('response.json():', data);

    /* @param {Date} epoch
     * Time of when translation object was created
     *
     * @param {string} action
     * Type of the message
     *
     * @param {string} sourceLanguage
     * Language of the original text
     *
     * @param {string} sourceText
     * User selected/highlighted (orignal) text
     *
     * @param {Object} sourceTextSynonyms
     * Synonyms for sourceText, organized by part of speach
     *
     * @param {Object} sourceTextDefinitions
     * Definitions and examples for sourceText, organized by part of speach
     *
     * @param {string} targetLanguage
     * Language of the translation text
     *
     * @param {string|null} targetText
     * Translation text for sourceText
     *
     * @param {Object|null} targetTextSynonyms
     * Synonyms for targetText, organized by part of speach
     */
    return {
      sourceLanguage: getLanguageForCode(data.src) || params.sourceLanguage,
      sourceText: sourceText,
      sourceTextSynonyms: getSourceTextSynonyms(data),
      sourceTextDefinitions: getSourceTextDefinitions(data),
      targetLanguage: params.targetLanguage,
      targetText: getTargetText(data),
      targetTextSynonyms: getTargetTextSynonyms(data)
    };
  }
  catch(error) {
    console.error(`Failure executing fetch(${translateURL}, {method:'GET',mode:'cors'}):`, error);
    throw new Error(error);
  }
}


/* @param {string} sourceText
   Text to be translated
 *
 * @param {Object} params 
 * Language params for the text translation: sourceLanguage, targetLanguage
 *
 * @returns {Object|null}
 * Object containing translation related properties for sourceText if successful, null otherwise
 * sourceLanguage, sourceText, sourceTextSynonyms, sourceTextDefinitions, targetLanguage, targetText,
 * targetTextSynonyms */
async function translateText(sourceText, params) {

  /* Let background.js handle the exception */
  if (typeof(sourceText) !== 'string')
    throw new TypeError(`Cannot translate data of type ${typeof(sourceText)}.`);

  sourceText = sourceText.trim();

  if (!sourceText)
    throw new TypeError('Cannot translate empty strings.');

  params = params || {};

  /* Source Language defaults to Auto-detected (language will be detected by Google Translate) */
  if (!('sourceLanguage' in params) || !isSupported(params.sourceLanguage)) {
    console.warn('Did not find a matching sourceLanguage, will default to Auto-detect.');
    params.sourceLanguage =  'Auto-detect'
  }

  /* Target Language defaults to English */
  if (!('targetLanguage' in params) || !isSupported(params.targetLanguage)) {
    console.warn('Did not find a matching targetLanguage, will default to English.');
    params.targetLanguage = 'English';
  }

  if (params.sourceLanguage == params.targetLanguage)
    throw new Error('sourceLanguage cannot equal to targetLanguage.');

  /* Preferred way of translating text */
  const result = await getAPITranslation(sourceText, params);
  console.debug(`getAPITranslation(${sourceText}, ${JSON.stringify(params)}):`, result);

  if (result === null)
    // Something went wrong. Try a tab translation, getTabTranslation(sourceText, params);
  
  return result;
}

export {translateText};
