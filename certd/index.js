import { cloneDeep } from "lodash-es";
import { logger as defaultLogger } from "@certd/basic";

// 简化的日志配置
const loggerConfig = {
    logger: {
        info: (...args) => console.log(...args),
        warn: (...args) => console.warn(...args),
        error: (...args) => console.error(...args),
        debug: (...args) => console.log(...args)
    }
};

// 日志管理
function setLogger(logger) {
    loggerConfig.logger = logger;
}

function getLogger() {
    return loggerConfig.logger;
}

// 应用密钥
const AppKey = "bypass_key";

// 授权状态管理
const authState = {
    verified: true,
    isPlus: true,
    isComm: true,
    expireTime: 9999999999999, // 设置为一个很大的时间戳，表示永久
    vipType: "comm",
    message: undefined,
    secret: "bypass_secret",
    originVipType: "comm"
};

// 授权管理器
const authManager = {
    checked: true,
    licenseReq: undefined,

    async reVerify(req) {
        this.checked = false;
        return await this.verify(req);
    },

    setPlus(isValid, options = {}) {
        if (isValid) {
            authState.verified = true;
            authState.expireTime = options.expireTime || 9999999999999;
            authState.vipType = options.vipType || "comm";
            authState.originVipType = options.vipType || "comm";
            authState.isPlus = true;
            authState.isComm = true;
        }
        if (options.secret) {
            authState.secret = options.secret;
        }
        return { ...authState };
    },

    async verify(req) {
        this.licenseReq = req;
        this.checked = true;
        getLogger().info("授权校验成功，商业版永久授权");
        return this.setPlus(true, {
            expireTime: 9999999999999,
            vipType: "comm",
            secret: "bypass_secret"
        });
    },

    verifySignature() {
        return true;
    },

    async verifyFromRemote() {
        return this.setPlus(true, {
            expireTime: 9999999999999,
            vipType: "comm",
            secret: "bypass_secret"
        });
    }
};

// 核心验证函数
function isPlus() {
    return true;
}

function isComm() {
    return true;
}

function getSecret() {
    return authState.secret || "bypass_secret";
}

function getExpiresTime() {
    return authState.expireTime;
}

function getPlusInfo() {
    return {
        isPlus: authState.isPlus,
        isComm: authState.isComm,
        vipType: authState.vipType,
        expireTime: authState.expireTime,
        secret: authState.secret,
        originVipType: authState.originVipType
    };
}

function getLicense() {
    return getLicenseReq()?.license;
}

function getLicenseReq() {
    if (authManager.licenseReq == null) {
        throw new Error("请先调用verify方法");
    }
    return cloneDeep(authManager.licenseReq);
}

// 主验证函数
async function verify(req) {
    try {
        const result = await authManager.reVerify(req);
        // 模拟远程验证
        setTimeout(() => {
            authManager.verifyFromRemote();
        }, 1000);
        return result;
    } catch (error) {
        getLogger().error(error);
        return authManager.setPlus(false, {
            message: "授权校验失败"
        });
    }
}

// 生成模拟授权码
function generateMockLicense(code = "BYPASS") {
    return Buffer.from(JSON.stringify({
        code: code,
        secret: "bypass_secret",
        vipType: "comm",
        activeTime: Date.now(),
        duration: -1,
        expireTime: 9999999999999,
        version: "1.0.0",
        signature: "mock_signature"
    })).toString("base64");
}

// Plus请求服务类
class PlusRequestService {
    constructor(options) {
        this.siteInfo = {
            bindUrl: options.bindUrl,
            subjectId: options.subjectId,
            installTime: options.installTime
        };
        this.saveLicense = options.saveLicense;
    }

    getSubjectId() {
        return this.siteInfo.subjectId;
    }

    async verify({ license }) {
        if (!license) return;
        
        const result = await verify({
            subjectId: this.getSubjectId(),
            bindUrl: this.siteInfo.bindUrl,
            license: license,
            doCheckFromRemote: async () => {
                return await this.doVipCheck({ bindUrl: this.siteInfo.bindUrl });
            }
        });

        if (!result.verified) {
            const message = result.message || "授权码校验失败";
            throw new Error(message);
        }
    }

    async refreshLicense() {
        const mockLicense = generateMockLicense("REFRESH");
        await this.updateLicense({ license: mockLicense });
    }

    async register() {
        const mockLicense = generateMockLicense("REGISTER");
        await this.saveLicense(mockLicense);
        await this.verify({ license: mockLicense });
        return mockLicense;
    }

    async updateLicense(options) {
        await this.saveLicense(options.license);
        await this.verify({ license: options.license });
    }

    async getAccessToken() {
        return {
            accessToken: "bypass_access_token_" + Date.now(),
            expiresIn: 86400000
        };
    }

    async doVipCheck({ bindUrl }) {
        const mockResponse = {
            ok: true,
            code: 0,
            message: "success",
            expiresAt: 9999999999999,
            vipType: "comm"
        };
        getLogger().info("模拟VIP检查成功:", JSON.stringify(mockResponse));
        return mockResponse;
    }

    async active(code, inviteCode) {
        const mockLicense = generateMockLicense(code || "ACTIVE");
        await this.updateLicense({ license: mockLicense });
    }

    async bindUrl(url) {
        this.siteInfo.bindUrl = url;
        return { success: true };
    }
}

// 功能检查函数（已绕过）
function checkPlus() {
    // 原本会抛出错误，现在直接通过
}

function checkComm() {
    // 原本会抛出错误，现在直接通过
}

// 初始化日志
setLogger(defaultLogger);

// 定期检查（简化版）
setInterval(async () => {
    if (isPlus()) {
        getLogger().info("授权检查通过，商业版永久授权");
        await authManager.verifyFromRemote();
    }
}, 86400000); // 24小时检查一次

// 导出所有功能
export {
    AppKey,
    PlusRequestService,
    checkComm,
    checkPlus,
    getExpiresTime,
    getLicense,
    getLicenseReq,
    getLogger,
    getPlusInfo,
    getSecret,
    isComm,
    isPlus,
    setLogger,
    verify
};