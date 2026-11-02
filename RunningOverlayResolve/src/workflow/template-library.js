'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const { invariant } = require('../domain/validation');
const { normalizeTemplateName, normalizeElements, normalizeUserTemplate, parseTemplateFile, serializeTemplateFile } = require('../domain/user-templates');

const MAXIMUM_TEMPLATE_FILE_BYTES = 64 * 1024 * 1024;

// Saved templates are shared by every Resolve project on this machine, like the
// Mac app's template library. Applying one copies it into the configuration.
class TemplateLibrary {
  constructor(file) { this.file = file; }
  async list() {
    try {
      const value = JSON.parse(await fs.readFile(this.file, 'utf8'));
      invariant(value.schemaVersion === 1 && Array.isArray(value.templates), 'The template library needs a newer version of Running Overlay.');
      return value.templates.map(normalizeUserTemplate);
    } catch (error) { if (error.code === 'ENOENT') return []; throw error; }
  }
  async write(templates) {
    await fs.mkdir(path.dirname(this.file), { recursive: true, mode: 0o700 });
    const temporary = `${this.file}.${crypto.randomUUID()}.tmp`;
    try { await fs.writeFile(temporary, `${JSON.stringify({ schemaVersion: 1, templates })}\n`, { mode: 0o600 }); await fs.rename(temporary, this.file); }
    finally { await fs.rm(temporary, { force: true }); }
    return templates;
  }
  async change(id, update) {
    const templates = await this.list();
    invariant(templates.some((template) => template.id === id), 'This template is no longer in the library.');
    return this.write(templates.flatMap((template) => template.id === id ? update(template) : [template]));
  }
  static nextName(templates) {
    const names = new Set(templates.map((template) => template.name));
    let index = 1;
    while (names.has(`Template ${index}`)) index += 1;
    return `Template ${index}`;
  }
  async add(elements) {
    const templates = await this.list();
    const template = { id: crypto.randomUUID(), name: TemplateLibrary.nextName(templates), elements: normalizeElements(elements) };
    return { template, templates: await this.write([...templates, template]) };
  }
  rename(id, name) { return this.change(id, (template) => [{ ...template, name: normalizeTemplateName(name) }]); }
  update(id, elements) { return this.change(id, (template) => [{ ...template, elements: normalizeElements(elements) }]); }
  duplicate(id) {
    return this.change(id, (template) => [template, { ...template, id: crypto.randomUUID(), name: normalizeTemplateName(`${template.name.slice(0, 75)} Copy`) }]);
  }
  remove(id) { return this.change(id, () => []); }
  async importFile(file) {
    const { size } = await fs.stat(file);
    invariant(size <= MAXIMUM_TEMPLATE_FILE_BYTES, 'This template file is too large.');
    const { template, stylesImported } = parseTemplateFile(await fs.readFile(file, 'utf8'));
    const templates = await this.list();
    const imported = { id: crypto.randomUUID(), ...template };
    return { template: imported, stylesImported, templates: await this.write([...templates, imported]) };
  }
  async exportFile(id, file) {
    const template = (await this.list()).find((candidate) => candidate.id === id);
    invariant(template, 'This template is no longer in the library.');
    await fs.writeFile(file, serializeTemplateFile(template), { mode: 0o600 });
  }
}

module.exports = { TemplateLibrary };
