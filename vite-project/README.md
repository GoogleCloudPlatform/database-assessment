# Vite + Vue + Shadcn Single Offline Page Prototype

## Install

```
npm ci install
npm run shadcn-components
```

## Build Template

```
npm run build
```

## Create Report

```
cp dist/index.html public/report.html
```

Edit `public/report.html` and replace `__DATA_TOKEN__` with the following array:

```
[{
    url: 'api/url1',
    key: 'hello from api/url1'
}, {
    url: 'api/url2',
    key: 'hello from api/url2'
}];
```

## Serve

```
python3 -m http.server 8080 -d public/
```

Open the page in your browser.
