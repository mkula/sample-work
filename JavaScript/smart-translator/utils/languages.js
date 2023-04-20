/* languages.js 
 * Utility module allowing for mapping between Language Name and Language Code (ISO-631-9) */
'use strict';

/* List of Google Translate supported languages */
const languageCode = {
 'Auto-detect': 'auto',
 'Afrikaans': 'af',
 'Albanian': 'sq',
 'Amharic': 'am',
 'Arabic': 'ar',
 'Armenian': 'hy',
 'Azerbaijani': 'az',
 'Basque': 'eu',
 'Belarusian': 'be',
 'Bengali': 'bn',
 'Bosnian': 'bs',
 'Bulgarian': 'bg',
 'Catalan': 'ca',
 'Cebuano': 'ceb',
 'Chichewa': 'ny',
 'Chinese Simplified': 'zh-cn',
 'Chinese Traditional': 'zh-tw',
 'Corsican': 'co',
 'Croatian': 'hr',
 'Czech': 'cs',
 'Danish': 'da',
 'Dutch': 'nl',
 'English': 'en',
 'Esperanto': 'eo',
 'Estonian': 'et',
 'Filipino': 'tl',
 'Finnish': 'fi',
 'French': 'fr',
 'Frisian': 'fy',
 'Galician': 'gl',
 'Georgian': 'ka',
 'German': 'de',
 'Greek': 'el',
 'Gujarati': 'gu',
 'Haitian Creole': 'ht',
 'Hausa': 'ha',
 'Hawaiian': 'haw',
 'Hebrew': 'iw',
 'Hindi': 'hi',
 'Hmong': 'hmn',
 'Hungarian': 'hu',
 'Icelandic': 'is',
 'Igbo': 'ig',
 'Indonesian': 'id',
 'Irish': 'ga',
 'Italian': 'it',
 'Japanese': 'ja',
 'Javanese': 'jw',
 'Kannada': 'kn',
 'Kazakh': 'kk',
 'Khmer': 'km',
 'Korean': 'ko',
 'Kurdish (Kurmanji)': 'ku',
 'Kyrgyz': 'ky',
 'Lao': 'lo',
 'Latin': 'la',
 'Latvian': 'lv',
 'Lithuanian': 'lt',
 'Luxembourgish': 'lb',
 'Macedonian': 'mk',
 'Malagasy': 'mg',
 'Malay': 'ms',
 'Malayalam': 'ml',
 'Maltese': 'mt',
 'Maori': 'mi',
 'Marathi': 'mr',
 'Mongolian': 'mn',
 'Myanmar (Burmese)': 'my',
 'Nepali': 'ne',
 'Norwegian': 'no',
 'Pashto': 'ps',
 'Persian': 'fa',
 'Polish': 'pl',
 'Portuguese': 'pt',
 'Punjabi': 'ma',
 'Romanian': 'ro',
 'Russian': 'ru',
 'Samoan': 'sm',
 'Scots Gaelic': 'gd',
 'Serbian': 'sr',
 'Sesotho': 'st',
 'Shona': 'sn',
 'Sindhi': 'sd',
 'Sinhala': 'si',
 'Slovak': 'sk',
 'Slovenian': 'sl',
 'Somali': 'so',
 'Spanish': 'es',
 'Sundanese': 'su',
 'Swahili': 'sw',
 'Swedish': 'sv',
 'Tajik': 'tg',
 'Tamil': 'ta',
 'Telugu': 'te',
 'Thai': 'th',
 'Turkish': 'tr',
 'Ukrainian': 'uk',
 'Urdu': 'ur',
 'Uzbek': 'uz',
 'Vietnamese': 'vi',
 'Welsh': 'cy',
 'Xhosa': 'xh',
 'Yiddish': 'yi',
 'Yoruba': 'yo',
 'Zulu': 'zu'
};

/* @param {string} language 
 * @returns {string|null} ISO 639-1 code of language if supported, null otherwise */
function getCodeForLanguage(language) {
  if (typeof(language) !== 'string') return null;

  language = language.toLowerCase().trim();

  if (!language) return null;

  const matches =  Object.entries(languageCode).filter(([key, value]) => {
    return key.toLowerCase().trim() === language;
  });

  return matches[0][1].trim() || null;  // string|null
}

/* @param {string} code ISO 639-1
 * @returns {string|null} language of ISO-639-1 code if supported, null otherwise */
function getLanguageForCode(code) {
  if (typeof(code) !== 'string') return null;

  code = code.toLowerCase().trim();

  if (!code) return null;

  const matches = Object.entries(languageCode).filter(([key, value]) => {
    return value.toLowerCase().trim() === code;
  });

  return matches[0][0].trim() || null;  // string|null
}

/* @param {string} name
 * @returns {boolean} true if language or code is supported, false otherwise */
function isSupported(name) {
  /* name contains Language and is supported */
  if (getCodeForLanguage(name)) return true;

  /* name contains Code and is supported */
  if (getLanguageForCode(name)) return true;

  /* name is not supported */
  return false;
}

export {languageCode, getCodeForLanguage, getLanguageForCode, isSupported};
