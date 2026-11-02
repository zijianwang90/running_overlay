'use strict';

const { app, BrowserWindow, dialog, ipcMain } = require('electron');
const fsSync = require('node:fs');
const path = require('node:path');
const WorkflowIntegration = require('./WorkflowIntegration.node');
const { loadActivityFile } = require('./lib/activity/import-activity');
const { ConfigurationStore } = require('./lib/workflow/configuration');
const { WorkflowService } = require('./lib/workflow/service');
const { fetchActivityWeather } = require('./lib/weather/weather');
const { TemplateLibrary } = require('./lib/workflow/template-library');

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

async function chooseTemplateImport() {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: 'Import overlay template',
    properties: ['openFile'],
    filters: [{ name: 'Overlay templates', extensions: ['rortemplate', 'rotemplate'] }],
  });
  return result.canceled || result.filePaths.length === 0 ? null : result.filePaths[0];
}

async function chooseTemplateExport(name) {
  const result = await dialog.showSaveDialog(mainWindow, {
    title: 'Export overlay template',
    defaultPath: `${path.basename(name)}.rortemplate`,
    filters: [{ name: 'Resolve overlay template', extensions: ['rortemplate'] }],
  });
  return result.canceled ? null : result.filePath;
}

function registerHandlers() {
  const panelWindow = (event) => {
    if (!mainWindow || event.sender !== mainWindow.webContents) throw new Error('Unknown panel window.');
    return mainWindow;
  };
  ipcMain.handle('window:minimize', (event) => { panelWindow(event).minimize(); });
  ipcMain.handle('window:close', (event) => { panelWindow(event).close(); });
  const service = new WorkflowService({ getResolve,
    store: new ConfigurationStore(path.join(app.getPath('userData'), 'configurations')),
    bundleRoot: path.join(app.getPath('userData'), 'bundles'),
  });
  const library = new TemplateLibrary(path.join(app.getPath('userData'), 'templates.json'));
  const templateHandler = (channel, work) => ipcMain.handle(channel, (event, payload) => { panelWindow(event); return service.exclusive(() => work(payload ?? {})); });
  templateHandler('templates:list', () => library.list());
  templateHandler('templates:saveCurrent', async (payload) => library.add(await service.currentTemplateElements(payload)));
  templateHandler('templates:updateFromCurrent', async ({ id, ...payload }) => library.update(id, await service.currentTemplateElements(payload)));
  templateHandler('templates:rename', ({ id, name }) => library.rename(id, name));
  templateHandler('templates:duplicate', ({ id }) => library.duplicate(id));
  templateHandler('templates:delete', ({ id }) => library.remove(id));
  templateHandler('templates:import', async () => {
    const file = await chooseTemplateImport();
    return file ? library.importFile(file) : null;
  });
  templateHandler('templates:export', async ({ id, name }) => {
    const file = await chooseTemplateExport(name);
    if (file) await library.exportFile(id, file);
    return Boolean(file);
  });
  ipcMain.handle('activity:choose', chooseActivityFile);
  // Only the historical activity weather request is exposed; the renderer cannot
  // choose arbitrary URLs. The result is cached in the saved configuration.
  ipcMain.handle('weather:fetch', (event, payload) => { panelWindow(event); return fetchActivityWeather(payload?.activity); });
  ipcMain.handle('resolve:scanTimeline', (_event, request) => service.exclusive(() => service.scanContext(request?.trackIndex, request?.contextId)));
  ipcMain.handle('configuration:save', (_event, payload) => service.exclusive(() => service.saveConfiguration(payload)));
  ipcMain.handle('overlay:apply', (_event, payload) => service.exclusive(() => service.apply(payload)));
  // Not queued behind scans: timing nudges must feel immediate while the user watches.
  ipcMain.handle('overlay:setTimeOffset', (_event, payload) => service.setTimeOffset(payload));
  ipcMain.handle('overlay:readPieceOffset', (_event, payload) => service.readPieceOffset(payload));
  ipcMain.handle('resolve:cleanup', () => service.exclusive(async () => {
    if (initialized) WorkflowIntegration.CleanUp();
    initialized = false;
    resolvePromise = null;
    return true;
  }));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    frame: false,
    width: 520,
    height: 760,
    minWidth: 460,
    minHeight: 620,
    useContentSize: true,
    backgroundColor: '#282828',
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
