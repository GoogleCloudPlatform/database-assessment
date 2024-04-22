declare var apidata: any

export function invoicesRaw() {
  return apidata.filter((x: { domain: string }) => x.domain == "invoices")[0]
    .data
}

export function invoicesTotalRevenue() {
  return invoicesRaw().reduce((a, b) => a + Number(b.totalAmount), 0)
}

export function invoicesNumberSales() {
  return invoicesRaw().length
}

export function purchasesRaw() {
  return apidata.filter((x: { domain: string }) => x.domain == "purchases")[0]
    .data
}
