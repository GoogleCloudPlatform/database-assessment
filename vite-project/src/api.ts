declare var apidata: any;

export function api(url: string)  {
    return {   
            url: url,
            key: apidata.filter((x: { url: string; }) => x.url == url)[0].key,
        };
}
