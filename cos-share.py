#!/usr/bin/env python3
"""
cos-share.py — 腾讯 COS 文件管理

COS 路径规范:
  /projects/<项目名>/assets/      — 项目素材
  /projects/<项目名>/releases/    — 发布包
  /projects/<项目名>/presets/     — 参数预设
  /shared/assets/                 — 跨项目共享素材
  /shared/presets/                — 跨项目共享预设

用法:
  cos-share.py upload <文件> [项目名] [类型]   上传文件
    类型: assets(默认) / releases / presets
  cos-share.py list [项目名]                    列出文件
  cos-share.py share <COS路径>                  生成7天下载链接
  cos-share.py download <COS路径> [本地路径]    下载文件
  cos-share.py delete <COS路径>                 删除文件
"""
import sys, os, json
from pathlib import Path
from datetime import datetime

CONFIG_PATH = Path.home() / ".seedance" / "config.json"

def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)

def get_client():
    from qcloud_cos import CosConfig, CosS3Client
    cfg = load_config()
    config = CosConfig(Region=cfg["cos_region"], SecretId=cfg["cos_secret_id"], SecretKey=cfg["cos_secret_key"])
    return CosS3Client(config), cfg["cos_bucket"], cfg["cos_region"]

def upload(filepath, project=None, category="assets"):
    filepath = Path(filepath).expanduser().resolve()
    if not filepath.exists():
        print(f"ERROR: 文件不存在: {filepath}")
        sys.exit(1)
    client, bucket, region = get_client()
    if project:
        key = f"projects/{project}/{category}/{filepath.name}"
    else:
        key = f"shared/{category}/{filepath.name}"
    size_mb = filepath.stat().st_size / 1024 / 1024
    print(f"上传: {filepath.name} ({size_mb:.1f}MB) → cos://{bucket}/{key}")
    if size_mb > 100:
        client.upload_file(Bucket=bucket, LocalFilePath=str(filepath), Key=key, EnableMD5=True, partSize=10*1024*1024)
    else:
        with open(filepath, "rb") as f:
            client.put_object(Bucket=bucket, Body=f, Key=key)
    url = f"https://{bucket}.cos.{region}.myqcloud.com/{key}"
    print(f"✓ 上传成功")
    print(f"  COS路径: {key}")
    print(f"  下载链接: {url}")
    return url

def list_files(prefix=None):
    client, bucket, region = get_client()
    if prefix:
        cos_prefix = f"projects/{prefix}/" if not prefix.startswith("projects/") else prefix
    else:
        cos_prefix = ""
    marker = ""
    total = 0
    while True:
        resp = client.list_objects(Bucket=bucket, Prefix=cos_prefix, Marker=marker, MaxKeys=100)
        contents = resp.get("Contents", [])
        if not contents:
            if not marker:
                print("  (空)")
            break
        for obj in contents:
            key = obj["Key"]
            size = int(obj["Size"])
            date = obj["LastModified"][:10]
            if size > 1024*1024:
                s = f"{size/1024/1024:.1f}MB"
            elif size > 1024:
                s = f"{size/1024:.1f}KB"
            else:
                s = f"{size}B"
            print(f"  {date}  {s:>10}  {key}")
            total += 1
        if resp.get("IsTruncated") == "true":
            marker = resp.get("NextMarker", contents[-1]["Key"])
        else:
            break
    print(f"\n共 {total} 个文件")

def share(key):
    client, bucket, region = get_client()
    signed = client.get_presigned_url(Method="GET", Bucket=bucket, Key=key, Expires=7*24*3600)
    print(f"文件: {key}")
    print(f"预签名链接(7天): {signed}")

def download(key, local_path=None):
    client, bucket, region = get_client()
    if not local_path:
        local_path = os.path.basename(key)
    client.download_file(Bucket=bucket, Key=key, DestFilePath=local_path)
    print(f"✓ 已下载: {key} → {local_path}")

def delete(key):
    client, bucket, region = get_client()
    client.delete_object(Bucket=bucket, Key=key)
    print(f"✓ 已删除: {key}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)
    cmd = sys.argv[1]
    if cmd == "upload" and len(sys.argv) >= 3:
        project = sys.argv[3] if len(sys.argv) >= 4 else None
        category = sys.argv[4] if len(sys.argv) >= 5 else "assets"
        upload(sys.argv[2], project, category)
    elif cmd == "list":
        prefix = sys.argv[2] if len(sys.argv) >= 3 else None
        list_files(prefix)
    elif cmd == "share" and len(sys.argv) >= 3:
        share(sys.argv[2])
    elif cmd == "download" and len(sys.argv) >= 3:
        local = sys.argv[3] if len(sys.argv) >= 4 else None
        download(sys.argv[2], local)
    elif cmd == "delete" and len(sys.argv) >= 3:
        delete(sys.argv[2])
    else:
        print(__doc__)
