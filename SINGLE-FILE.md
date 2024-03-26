# Vite + Vue + Shadcn Single Offline Page Prototype

## Install

```
npm ci install
```

## Build Template

```
npm run build
```

## Create Report

```
cp src/dma/static/index.html src/dma/static/report.html
```

Edit `src/dma/static/report.html` and replace `__DATA_TOKEN__` with the following array:

```
[{
    domain: 'invoices',
    data: [
        {
            invoice: "INV001",
            paymentStatus: "Paid",
            totalAmount: "250.49",
            paymentMethod: "Credit Card",
        },
        {
            invoice: "INV002",
            paymentStatus: "Pending",
            totalAmount: "150.23",
            paymentMethod: "PayPal",
        }
    ]
},
{
    domain: 'purchases',
    data: [
        {
            name: "Jan",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Feb",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Mar",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Apr",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "May",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Jun",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Jul",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Aug",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Sep",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Oct",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Nov",
            total: Math.floor(Math.random() * 5000) + 1000,
        },
        {
            name: "Dec",
            total: Math.floor(Math.random() * 5000) + 1000,
        }
    ]
}];
```

## Serve

```
python3 -m http.server 8080 -d src/dma/static/
```

Open the `report.html` page in your browser.
