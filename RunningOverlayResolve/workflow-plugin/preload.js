'use strict';

const { contextBridge, ipcRenderer } = require('electron/renderer');

contextBridge.exposeInMainWorld('runningOverlayAPI', {
  chooseActivity: () => ipcRenderer.invoke('activity:choose'),
  scanTimeline: (request) => ipcRenderer.invoke('resolve:scanTimeline', request),
  saveConfiguration: (payload) => ipcRenderer.invoke('configuration:save', payload),
  applyOverlay: (payload) => ipcRenderer.invoke('overlay:apply', payload),
  cleanup: () => ipcRenderer.invoke('resolve:cleanup'),
  minimizeWindow: () => ipcRenderer.invoke('window:minimize'),
  closeWindow: () => ipcRenderer.invoke('window:close'),
});
