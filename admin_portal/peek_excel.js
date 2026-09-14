import xlsx from 'xlsx';

const workbook = xlsx.readFile('C:\\Users\\phani\\StudioProjects\\elite_app\\Combined Student List.xlsx');
const sheetName = workbook.SheetNames[0];
const sheet = workbook.Sheets[sheetName];
const data = xlsx.utils.sheet_to_json(sheet, { header: 1 });

console.log("Headers:", data[0]);
console.log("Row 1:", data[1]);
console.log("Row 2:", data[2]);
console.log("Total rows:", data.length);
