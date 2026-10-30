import { stripTypeScriptTypes } from 'node:module';
import { readdir, readFile, mkdir, writeFile } from 'node:fs/promises';
const source = new URL('./src/', import.meta.url);
const destination = new URL('./dist/', import.meta.url);
await mkdir(destination, { recursive: true });
for (const file of await readdir(source)) {
  if (!file.endsWith('.ts')) continue;
  const content = await readFile(new URL(file, source), 'utf8');
  const javascript = stripTypeScriptTypes(content, { mode: 'strip', sourceUrl: file });
  await writeFile(new URL(file.replace(/\.ts$/, '.js'), destination), javascript);
  process.stdout.write(`${file}\n`);
}
