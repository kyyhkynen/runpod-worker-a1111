import time
import os

import runpod
import requests
from requests.adapters import HTTPAdapter, Retry
from runpod.serverless.modules.rp_logger import RunPodLogger

WEBUI_PORT = os.environ.get("WEBUI_PORT", 3000)
BASE_URL = f"http://127.0.0.1:{WEBUI_PORT}"
TIMEOUT = 600

session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
session.mount("http://", HTTPAdapter(max_retries=retries))
logger = RunPodLogger()


# ---------------------------------------------------------------------------- #
#                              Automatic Functions                             #
# ---------------------------------------------------------------------------- #
def wait_for_service(url):
    """
    Check if the service is ready to receive requests.
    """
    retries = 0
    while True:
        try:
            requests.get(url)
            return
        except requests.exceptions.RequestException:
            # Only log every 15 retries so the logs don't get spammed
            if retries % 15 == 0:
                logger.info("Service not ready yet. Retrying...")
            retries += 1
        except Exception as err:
            logger.error(f"Error: {err}")

        time.sleep(0.2)


def send_get_request(endpoint):
    return session.get(url=f"{BASE_URL}/{endpoint}", timeout=TIMEOUT)


def send_post_request(endpoint, payload):
    return session.post(url=f"{BASE_URL}/{endpoint}", json=payload, timeout=TIMEOUT)


# ---------------------------------------------------------------------------- #
#                                RunPod Handler                                #
# ---------------------------------------------------------------------------- #
def handler(event):
    """
    This is the handler function that will be called by the serverless.
    """

    method = event["input"]["method"]
    endpoint = event["input"]["endpoint"]
    payload = {}
    if "payload" in event["input"]:
        payload = event["input"]["payload"]

    try:
        if method == "GET":
            response = send_get_request(endpoint)
        elif method == "POST":
            response = send_post_request(endpoint, payload)
    except Exception as e:
        return {"error": str(e)}

    return response.json()


if __name__ == "__main__":
    wait_for_service(url=f"{BASE_URL}/sdapi/v1/sd-models")

    print("WebUI API Service is ready. Starting RunPod...")

    runpod.serverless.start({"handler": handler})
