const res = await fetch('http://127.0.0.1:8085/');
console.log("Status:", res.status);
const html = await res.text();
console.log("HTML length:", html.length);
console.log("HTML preview:\n", html.slice(0, 1000));
