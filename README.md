# learnsite-docker
OpenLearnSite信息科技学习平台Docker部署文件
- OpenLearnSite运行环境：
[![dev 最后更新](https://img.shields.io/badge/dynamic/json?label=dev%20%E6%9C%80%E5%90%8E%E6%9B%B4%E6%96%B0&query=%24.last_updated&url=https%3A%2F%2Fhub.docker.com%2Fv2%2Frepositories%2Forzg%2Flearnsite-web%2Ftags%2Fdev&color=blue&logo=docker)](https://hub.docker.com/r/orzg/learnsite-web)

- MSSQL数据库
[![latest 最后更新](https://img.shields.io/badge/dynamic/json?label=latest%20%E6%9C%80%E5%90%8E%E6%9B%B4%E6%96%B0&query=%24.last_updated&url=https%3A%2F%2Fhub.docker.com%2Fv2%2Frepositories%2Forzg%2Fmssql-learnsite%2Ftags%2Flatest&color=blue&logo=docker)](https://hub.docker.com/r/orzg/mssql-learnsite)

# docker-compose.yaml 说明
- 如果是数据库和Learnsite环境分开部署，请参考部署指南：
https://www.aino.fun/archives/learnsite-guide

- 否则就用默认的docker-compose.yml修改相关环境变量后部署即可
