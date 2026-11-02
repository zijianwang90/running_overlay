'use strict';

const { contextBridge, ipcRenderer } = require('electron/renderer');

contextBridge.exposeInMainWorld('runningOverlayAPI', {
  chooseActivity: () => ipcRenderer.invoke('activity:choose'),
  fetchWeather: (payload) => ipcRenderer.invoke('weather:fetch', payload),
  scanTimeline: (request) => ipcRenderer.invoke('resolve:scanTimeline', request),
  saveConfiguration: (payload) => ipcRenderer.invoke('configuration:save', payload),
  applyOverlay: (payload) => ipcRenderer.invoke('overlay:apply', payload),
  setTimeOffset: (payload) => ipcRenderer.invoke('overlay:setTimeOffset', payload),
  readPieceOffset: (payload) => ipcRenderer.invoke('overlay:readPieceOffset', payload),
  listTemplates: () => ipcRenderer.invoke('templates:list'),
  saveCurrentTemplate: (payload) => ipcRenderer.invoke('templates:saveCurrent', payload),
  updateTemplateFromCurrent: (payload) => ipcRenderer.invoke('templates:updateFromCurrent', payload),
  renameTemplate: (payload) => ipcRenderer.invoke('templates:rename', payload),
  duplicateTemplate: (payload) => ipcRenderer.invoke('templates:duplicate', payload),
  deleteTemplate: (payload) => ipcRenderer.invoke('templates:delete', payload),
  importTemplate: () => ipcRenderer.invoke('templates:import'),
  exportTemplate: (payload) => ipcRenderer.invoke('templates:export', payload),
  cleanup: () => ipcRenderer.invoke('resolve:cleanup'),
  minimizeWindow: () => ipcRenderer.invoke('window:minimize'),
  closeWindow: () => ipcRenderer.invoke('window:close'),
});
