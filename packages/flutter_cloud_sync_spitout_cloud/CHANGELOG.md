# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Spitout Cloud provider 独立 Adapter 包
  - 从 `flutter_cloud_sync` 核心包迁移 `SpitoutCloudProvider`
  - 通过 `registerSpitoutCloudBackend()` 自注册到 `CloudProviderRegistry`
  - 消除核心包对 `crypto` / `device_info_plus` / `package_info_plus` / `http` / `web_socket_channel` 的寄生依赖
