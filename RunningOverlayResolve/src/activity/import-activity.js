'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const { activityIdFromPath, parseFitBuffer } = require('./fit-parser');
const { parseGpxBuffer } = require('./gpx-parser');
const { validateActivity } = require('../domain/activity');

async function loadActivityFile(filePath) {
  const data = await fs.readFile(filePath);
  const extension = path.extname(filePath).toLowerCase();
  if (extension === '.fit') return parseFitBuffer(data, { activityId: activityIdFromPath(filePath) });
  if (extension === '.gpx') return parseGpxBuffer(data, { activityId: activityIdFromPath(filePath) });
  if (extension === '.json') return validateActivity(JSON.parse(data.toString('utf8')));
  throw new Error('Choose a FIT, GPX, or normalized activity JSON file.');
}

module.exports = { loadActivityFile };
