import { NextResponse } from 'next/server'

interface Product {
  id: string
  name: string
  price: number
  originalPrice: number
  desc: string
  image: string
  tag: string
  rating: number
  sales: number
  stock: number
  coverHeight: number
}

const MOCK_PRODUCTS: Product[] = [
  { id: '001', name: 'ArkTS 快速入门',     price: 99,  originalPrice: 129, desc: '鸿蒙原生开发语言全解析', image: 'images/1.png', tag: '新品', rating: 4.8, sales: 1256, stock: 98,  coverHeight: 132 },
  { id: '002', name: 'HarmonyOS 实战',     price: 299, originalPrice: 399, desc: '从零到项目上线完整教程，涵盖登录、列表与网络请求。', image: 'images/1.png', tag: '热门', rating: 4.9, sales: 3280, stock: 56,  coverHeight: 194 },
  { id: '003', name: 'ArkUI 组件精讲',     price: 199, originalPrice: 259, desc: '企业级 UI 组件、布局与交互细节拆解。', image: 'images/1.png', tag: '推荐', rating: 4.7, sales: 1845, stock: 120, coverHeight: 158 },
  { id: '004', name: 'DevEco 效率指南',    price: 49,  originalPrice: 79,  desc: 'IDE 调试与性能优化技巧', image: 'images/1.png', tag: '',     rating: 4.6, sales: 932,  stock: 200, coverHeight: 120 },
  { id: '005', name: 'ArkUI 动画教程',     price: 149, originalPrice: 199, desc: '帧动画、转场与自定义动效，让交互更有生命力。', image: 'images/1.png', tag: '热门', rating: 4.8, sales: 1568, stock: 85,  coverHeight: 206 },
  { id: '006', name: '鸿蒙面试题库',       price: 79,  originalPrice: 99,  desc: '高频知识点、场景题与答题思路，适合碎片化复习。', image: 'images/1.png', tag: '必备', rating: 4.9, sales: 5120, stock: 300, coverHeight: 144 },
  { id: '007', name: 'HMRouter 路由实战',  price: 89,  originalPrice: 119, desc: '路由跳转、页面参数与复杂导航场景一次讲透。', image: 'images/1.png', tag: '新品', rating: 4.7, sales: 643,  stock: 150, coverHeight: 176 },
  { id: '008', name: 'ArkWeb 开发指南',    price: 129, originalPrice: 169, desc: 'Web 与原生混合开发的实用方案和踩坑整理。', image: 'images/1.png', tag: '推荐', rating: 4.8, sales: 890,  stock: 110, coverHeight: 126 },
  { id: '009', name: '鸿蒙网络请求实战',   price: 69,  originalPrice: 99,  desc: 'HTTP、SSE、上传下载等网络能力的完整实践。', image: 'images/1.png', tag: '热门', rating: 4.8, sales: 2341, stock: 180, coverHeight: 188 },
  { id: '010', name: 'ArkData 持久化指南', price: 119, originalPrice: 159, desc: 'Preferences、数据库与状态持久化的基础用法。', image: 'images/1.png', tag: '推荐', rating: 4.6, sales: 721,  stock: 140, coverHeight: 136 },
  { id: '011', name: '企业级鸿蒙架构设计', price: 399, originalPrice: 499, desc: '从模块拆分到 MVVM 分层，建立可维护的大型应用结构。', image: 'images/1.png', tag: '精品', rating: 5.0, sales: 980,  stock: 36,  coverHeight: 214 },
  { id: '012', name: '鸿蒙项目源码合集',   price: 199, originalPrice: 299, desc: '多个完整案例源码，覆盖登录、商城、聊天与数据管理。', image: 'images/1.png', tag: '热销', rating: 4.9, sales: 2860, stock: 75,  coverHeight: 152 }
]

export async function GET() {
  return NextResponse.json({
    code: 200,
    message: 'success',
    data: MOCK_PRODUCTS
  })
}
