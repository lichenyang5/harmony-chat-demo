import { NextResponse } from 'next/server'

// 「发现」Tab 的 ASCF 特性列表。
// demo 里 AscfFeatureImp 原本走本地 mock（USE_MOCK=true），
// 这个路由让它可以把 USE_MOCK 改成 false 走真接口，数据保持一致。
interface AscfFeature {
  id: string
  title: string
  desc: string
}

const FEATURES: AscfFeature[] = [
  { id: '1', title: '免安装', desc: '服务中心直接流转，无需下载安装包' },
  { id: '2', title: '一次开发', desc: '复用小程序资产，少量适配即可上架' },
  { id: '3', title: 'ASCF Toolkit', desc: 'hvigor 插件把工程自动编译成元服务' },
  { id: '4', title: 'ascfapi', desc: '元服务运行时能力（如增强 Web 组件）' },
]

// GET /api/ascf/features
export async function GET() {
  return NextResponse.json({
    code: 200,
    message: 'success',
    data: FEATURES,
  })
}
