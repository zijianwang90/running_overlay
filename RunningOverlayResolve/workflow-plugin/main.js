'use strict';

const { app, BrowserWindow, dialog, ipcMain } = require('electron');
const fsSync = require('node:fs');
const path = require('node:path');
const WorkflowIntegration = require('./WorkflowIntegration.node');
const { loadActivityFile } = require('./lib/activity/import-activity');
const { ConfigurationStore } = require('./lib/workflow/configuration');
const { WorkflowService } = require('./lib/workflow/service');

const PLUGIN_ID = 'com.runningoverlay.resolve';
const userDataDirectory = path.join(app.getPath('appData'), 'Running Overlay Resolve');
fsSync.mkdirSync(userDataDirectory, { recursive: true, mode: 0o700 });
app.setPath('userData', userDataDirectory);
app.setName('Running Overlay Resolve');
let mainWindow = null;
let initialized = false;
let resolvePromise = null;

async function getResolve() {
  if (!initialized) {
    initialized = await WorkflowIntegration.InitializePromise(PLUGIN_ID);
  }
  if (!initialized) throw new Error('Running Overlay could not connect to DaVinci Resolve.');
  if (!resolvePromise) resolvePromise = WorkflowIntegration.GetResolvePromise();
  return resolvePromise;
}

async function chooseActivityFile() {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: 'Choose FIT, GPX, or normalized Running Overlay activity data',
    properties: ['openFile'],
    filters: [{ name: 'Activity data', extensions: ['fit', 'gpx', 'json'] }],
  });
  if (result.canceled || result.filePaths.length === 0) return null;
  const filePath = result.filePaths[0];
  const activity = await loadActivityFile(filePath);
  return { activity, fileName: path.basename(filePath) };
}

function registerHandlers() {
  const service = new WorkflowService({ getResolve,
    store: new ConfigurationStore(path.join(app.getPath('userData'), 'configurations')),
    bundleRoot: path.join(app.getPath('userData'), 'bundles'),
  });
  ipcMain.handle('activity:choose', chooseActivityFile);
  ipcMain.handle('resolve:scanTimeline', (_event, request) => service.exclusive(() => service.scanContext(request?.trackIndex, request?.contextId)));
  ipcMain.handle('configuration:save', (_event, payload) => service.exclusive(() => service.saveConfiguration(payload)));
  ipcMain.handle('overlay:apply', (_event, payload) => service.exclusive(() => service.apply(payload)));
  ipcMain.handle('resolve:cleanup', () => service.exclusive(async () => {
    if (initialized) WorkflowIntegration.CleanUp();
    initialized = false;
    resolvePromise = null;
    return true;
  }));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 520,
    height: 760,
    minWidth: 460,
    minHeight: 620,
    useContentSize: true,
    backgroundColor: '#15171a',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  mainWindow.setMenu(null);
  mainWindow.loadFile('index.html');
  mainWindow.on('closed', () => { mainWindow = null; });
}

app.whenReady().then(() => {
  registerHandlers();
  createWindow();
});

app.on('window-all-closed', () => app.quit());
app.on('before-quit', () => {
  if (initialized) WorkflowIntegration.CleanUp();
});
