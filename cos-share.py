#!/usr/bin/env python3
"""
cos-share.py — 大文件上传腾讯 COS + 生成飞书共享链接
用法:
  cos-share.py upload <文件路径>     上传文件到 COS，返回下载链接
  cos-share.py list                  列出 COS 上的文件
  cos-share.py share <文件名>        生成临时预签名下载链接（1小时有效）
  cos-share.py delete <文件名>       删除 COS 上的文件
"""
import sys
import os
import json
import hashlib
from pathlib import Path
from datetime import datetime

CONFIG_PATH = Path.home() / ".seedance" / "config.json"
COS_PREFIX = "shared/"  # 共享文件前缀

def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)

def get_client():
    from qcloud_cos import CosConfig, CosS3Client
    cfg = load_config()
    config = CosConfig(
        Region=cfg["cos_region"],
        SecretId=cfg["cos_secret_id"],
        SecretKey=cfg["cos_secret_key"],
    )
    return CosS3Client(config), cfg["cos_bucket"], cfg["cos_region"]

def upload(filepath):
    filepath = Path(filepath).expanduser().resolve()
    if not filepath.exists():
        print(f"ERROR: 文件不存在: {filepath}")
        sys.exit(1)
    
    client, bucket, region = get_client()
    
    # 用日期+文件名组织路径
    date_prefix = datetime.now().strftime("%Y-%m")
    key = f"{COS_PREFIX}{date_prefix}/{filepath.name}"
    
    size_mb = filepath.stat().st_size / 1024 / 1024
    print(f"上传: {filepath.name} ({size_mb:.1f}MB) → cos://{bucket}/{key}")
    
    # 大文件用分块上传
    if size_mb > 100:
        response = client.upload_file(
            Bucket=bucket,
            LocalFilePath=str(filepath),
            Key=key,
            EnableMD5=True,
            partSize=10 * 1024 * 1024,  # 10MB 分块
        )
    else:
        with open(filepath, "rb") as f:
            client.put_object(Bucket=bucket, Body=f, Key=key)
    
    url = f"https://{bucket}.cos.{region}.myqcloud.com/{key}"
    print(f"\n✓ 上传成功")
    print(f"  下载链接: {url}")
    print(f"  飞书分享: 直接贴上面这个链接")
    
    # 如果是图片/视频，生成预签名链接（1小时）
    ext = filepath.suffix.lower()
    if ext in ['.mp4', '.mov', '.mp3', '.wav', '.png', '.jpg', '.jpeg', '.gif', '.webp']:
        signed = client.get_presigned_url(
            Method="GET",
            Bucket=bucket,
            Key=key,
            Expires=3600,
        )
        print(f"  预签名链接(1h): {signed}")
    
    return url

def list_files():
    client, bucket, region = get_client()
    marker = ""
    print(f"=== COS 文件列表 (prefix: {COS_PREFIX}) ===\n")
    while True:
        resp = client.list_objects(
            Bucket=bucket,
            Prefix=COS_PREFIX,
            Marker=marker,
            MaxKeys=100,
        )
        contents = resp.get("Contents", [])
        if not contents:
            if not marker:
                print("  (空)")
            break
        for obj in contents:
            key = obj["Key"]
            size = int(obj["Size"])
            date = obj["LastModified"][:10]
            if size > 1024 * 1024:
                size_str = f"{size / 1024 / 1024:.1f}MB"
            elif size > 1024:
                size_str = f"{size / 1024:.1f}KB"
            else:
                size_str = f"{size}B"
            print(f"  {date}  {size_str:>10}  {key}")
        if resp.get("IsTruncated") == "true":
            marker = resp.get("NextMarker", contents[-1]["Key"])
        else:
            break

def share(filename):
    client, bucket, region = get_client()
    # 搜索文件
    key = f"{COS_PREFIX}{filename}" if not filename.startswith(COS_PREFIX) else filename
    
    # 生成预签名链接（7天有效）
    signed = client.get_presigned_url(
        Method="GET",
        Bucket=bucket,
        Key=key,
        Expires=7 * 24 * 3600,
    )
    print(f"文件: {key}")
    print(f"预签名链接(7天): {signed}")

def delete(filename):
    client, bucket, region = get_client()
    key = f"{COS_PREFIX}{filename}" if not filename.startswith(COS_PREFIX) else filename
    client.delete_object(Bucket=bucket, Key=key)
    print(f"✓ 已删除: {key}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)
    
    cmd = sys.argv[1]
    if cmd == "upload" and len(sys.argv) >= 3:
        upload(sys.argv[2])
    elif cmd == "list":
        list_files()
    elif cmd == "share" and len(sys.argv) >= 3:
        share(sys.argv[2])
    elif cmd == "delete" and len(sys.argv) >= 3:
        delete(sys.argv[2])
    else:
        print(__doc__)
