export const S3DirectUploader = (entries, onError) => {
  entries.forEach((entry) => {
    const { url, method = "PUT", headers = [] } = entry.meta;
    const xhr = new XMLHttpRequest();

    onError(() => xhr.abort());

    xhr.open(method, url, true);

    headers.forEach(([key, value]) => {
      xhr.setRequestHeader(key, value);
    });

    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        entry.progress(Math.round((event.loaded / event.total) * 100));
      }
    });

    xhr.addEventListener("load", () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        entry.progress(100);
      } else {
        entry.error(`storage_${xhr.status}`);
      }
    });

    xhr.addEventListener("error", () => entry.error("storage_upload_failed"));
    xhr.addEventListener("abort", () => entry.error("storage_upload_aborted"));

    xhr.send(entry.file);
  });
};
