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
}

const MOCK_PRODUCTS: Product[] = [
  { id: '001', name: 'ArkTS 快速入门',     price: 99,  originalPrice: 129, desc: '鸿蒙原生开发语言全解析', image: 'images/1.png', tag: '新品', rating: 4.8, sales: 1256, stock: 98  },
  { id: '002', name: 'HarmonyOS 实战',     price: 299, originalPrice: 399, desc: '从零到项目上线完整教程', image: 'images/1.png', tag: '热门', rating: 4.9, sales: 3280, stock: 56  },
  { id: '003', name: 'ArkUI 组件精讲',     price: 199, originalPrice: 259, desc: '企业级 UI 组件与布局',   image: 'images/1.png', tag: '推荐', rating: 4.7, sales: 1845, stock: 120 },
  { id: '004', name: 'DevEco 效率指南',    price: 49,  originalPrice: 79,  desc: 'IDE 调试与性能优化技巧', image: 'images/1.png', tag: '',     rating: 4.6, sales: 932,  stock: 200 },
  { id: '005', name: 'ArkUI 动画教程',     price: 149, originalPrice: 199, desc: '帧动画、转场与自定义动效', image: 'images/1.png', tag: '热门', rating: 4.8, sales: 1568, stock: 85  },
  { id: '006', name: '鸿蒙面试题库',       price: 79,  originalPrice: 99,  desc: '高频知识点与答题技巧',   image: 'images/1.png', tag: '必备', rating: 4.9, sales: 5120, stock: 300 },
  { id: '007', name: 'HMRouter 路由实战',  price: 89,  originalPrice: 119, desc: '路由跳转与参数传递',     image: 'images/1.png', tag: '新品', rating: 4.7, sales: 643,  stock: 150 },
  { id: '008', name: 'ArkWeb 开发指南',    price: 129, originalPrice: 169, desc: 'Web 与原生混合开发',     image: 'images/1.png', tag: '推荐', rating: 4.8, sales: 890,  stock: 110 },
  { id: '009', name: '鸿蒙网络请求实战',   price: 69,  originalPrice: 99,  desc: 'HTTP、SSE、上传下载',     image: 'images/1.png', tag: '热门', rating: 4.8, sales: 2341, stock: 180 },
  { id: '010', name: 'ArkData 持久化指南', price: 119, originalPrice: 159, desc: 'Preferences 与数据库实践', image: 'images/1.png', tag: '推荐', rating: 4.6, sales: 721,  stock: 140 },
  { id: '011', name: '企业级鸿蒙架构设计', price: 399, originalPrice: 499, desc: 'MVVM 与模块化架构实战',   image: 'images/1.png', tag: '精品', rating: 5.0, sales: 980,  stock: 36  },
  { id: '012', name: '鸿蒙项目源码合集',   price: 199, originalPrice: 299, desc: '多个完整项目案例源码',   image: 'images/1.png', tag: '热销', rating: 4.9, sales: 2860, stock: 75  }
]

export async function GET() {
  return NextResponse.json({
    code: 200,
    message: 'success',
    data: MOCK_PRODUCTS
  })
}
