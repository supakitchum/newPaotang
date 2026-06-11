import type { OperationAction, OperationColumn, OperationFilter, OperationFormField, OperationOption } from '~/composables/useAdminOperationsCatalog'

const thaiLocales = new Set(['th', 'th-th', 'th-TH'])

const reportNames: Record<string, string> = {
  overview: 'ภาพรวม',
  sales: 'ยอดขาย',
  orders: 'คำสั่งซื้อ',
  customers: 'ลูกค้า',
  stock: 'คลังสลาก',
  wallet: 'กระเป๋าเงิน',
  commission: 'ค่าคอมมิชชัน',
  rewards: 'รางวัล',
  settlement: 'การชำระบัญชี',
  partner_usage: 'การใช้งานพาร์ทเนอร์',
  partners: 'พาร์ทเนอร์',
  audit: 'ประวัติตรวจสอบ',
}

const reportText: Record<string, string> = {
  'Action': 'การดำเนินการ',
  'Actor': 'ผู้ดำเนินการ',
  'Actor ID': 'ID ผู้ดำเนินการ',
  'Adjustment': 'ส่วนปรับเพิ่ม/ลด',
  'Admins': 'ผู้ดูแลระบบ',
  'Affiliate': 'Affiliate',
  'Allocated': 'จัดสรรแล้ว',
  'All': 'ทั้งหมด',
  'All draws': 'ทุกงวด',
  'All partner stores': 'ร้านค้าพาร์ทเนอร์ทั้งหมด',
  'Amount': 'จำนวนเงิน',
  'API': 'API',
  'Apply filters': 'ใช้ตัวกรอง',
  'Approved': 'อนุมัติแล้ว',
  'Approved at': 'เวลาอนุมัติ',
  'Area': 'ส่วนงาน',
  'Audit actions': 'การดำเนินการ Audit',
  'Auto reward': 'ขึ้นเงินอัตโนมัติ',
  'Available': 'พร้อมขาย',
  'Back 2': 'เลขท้าย 2 ตัว',
  'Back 3': 'เลขท้าย 3 ตัว',
  'Balance after': 'ยอดคงเหลือหลังรายการ',
  'Base prize': 'เงินรางวัลฐาน',
  'Bookings': 'รายการจอง',
  'Cancelled': 'ยกเลิกแล้ว',
  'Checkouts': 'ชำระเงิน',
  'Claims': 'คำขอขึ้นเงิน',
  'Code': 'รหัส',
  'Commission': 'ค่าคอมมิชชัน',
  'Commission by affiliate': 'ค่าคอมมิชชันตาม Affiliate',
  'Commission by partner store': 'ค่าคอมมิชชันตามร้านค้าพาร์ทเนอร์',
  'Commission status mix': 'สัดส่วนสถานะค่าคอมมิชชัน',
  'Count': 'จำนวน',
  'Created': 'เวลาสร้าง',
  'Cursor': 'เคอร์เซอร์',
  'Customer': 'ลูกค้า',
  'Customer preferences': 'การตั้งค่าของลูกค้า',
  'Customer status breakdown': 'สถานะลูกค้า',
  'Customers': 'ลูกค้า',
  'Date': 'วันที่',
  'Draw date': 'วันออกรางวัล',
  'Enabled': 'เปิดใช้งาน',
  'Entries': 'รายการ',
  'Errors': 'ข้อผิดพลาด',
  'Events': 'เหตุการณ์',
  'Export report': 'ส่งออกรายงาน',
  'Format': 'รูปแบบ',
  'From': 'ตั้งแต่',
  'Front 3': 'เลขหน้า 3 ตัว',
  'Game': 'เกม',
  'Game / draw': 'เกม / งวด',
  'Group by': 'จัดกลุ่มตาม',
  'Inflow': 'เงินเข้า',
  'Joined': 'วันที่สมัคร',
  'Latest': 'ล่าสุด',
  'Limit': 'จำนวนต่อหน้า',
  'Local stock by game': 'คลังสลากร้านค้าตามเกม',
  'Net': 'สุทธิ',
  'New customers': 'ลูกค้าใหม่',
  'New customers by partner store': 'ลูกค้าใหม่ตามร้านค้าพาร์ทเนอร์',
  'No data was returned for this report section.': 'ส่วนรายงานนี้ไม่มีข้อมูล',
  'No report rows': 'ไม่มีแถวรายงาน',
  'No report summary': 'ไม่มีสรุปรายงาน',
  'No options available': 'ไม่มีตัวเลือก',
  'No row-level report data was returned for the selected filters.': 'ไม่มีข้อมูลรายแถวของรายงานตามตัวกรองที่เลือก',
  'No section rows': 'ไม่มีข้อมูลในส่วนนี้',
  'No summary values were returned for this report.': 'รายงานนี้ไม่มีค่าสรุป',
  'Number': 'เลขสลาก',
  'Number segment coverage': 'Coverage ตามชุดเลข',
  'Operational status overview': 'ภาพรวมสถานะการดำเนินงาน',
  'Order ref': 'เลขอ้างอิงคำสั่งซื้อ',
  'Order status breakdown': 'สถานะคำสั่งซื้อ',
  'Orders': 'คำสั่งซื้อ',
  'Outflow': 'เงินออก',
  'Paid': 'ชำระแล้ว',
  'Paid at': 'เวลาชำระเงิน',
  'Partner': 'พาร์ทเนอร์',
  'Partner code': 'รหัสพาร์ทเนอร์',
  'Partner status': 'สถานะพาร์ทเนอร์',
  'Partner status mix': 'สัดส่วนสถานะพาร์ทเนอร์',
  'Partner store': 'ร้านค้าพาร์ทเนอร์',
  'Partners': 'พาร์ทเนอร์',
  'Payment': 'การชำระเงิน',
  'Payment method': 'วิธีชำระเงิน',
  'Payment method mix': 'สัดส่วนวิธีชำระเงิน',
  'Payment status': 'สถานะชำระเงิน',
  'Payment status breakdown': 'สถานะการชำระเงิน',
  'Payout': 'การจ่ายเงิน',
  'Payout method': 'วิธีรับเงิน',
  'Pending': 'รอดำเนินการ',
  'Period': 'ช่วงเวลา',
  'Phone': 'เบอร์โทร',
  'Posted': 'เวลาบันทึก',
  'Preference': 'การตั้งค่า',
  'Prize': 'เงินรางวัล',
  'Reference': 'อ้างอิง',
  'Reference ID': 'ID อ้างอิง',
  'Rejected': 'ปฏิเสธแล้ว',
  'Report': 'รายงาน',
  'Report rows': 'แถวรายงาน',
  'Report summary': 'สรุปรายงาน',
  'Reserved': 'จองแล้ว',
  'Reward claims': 'คำขอขึ้นเงินรางวัล',
  'Reward claims by partner store': 'คำขอขึ้นเงินรางวัลตามร้านค้าพาร์ทเนอร์',
  'Reward payout methods': 'วิธีรับเงินรางวัล',
  'Reward status mix': 'สัดส่วนสถานะรางวัล',
  'Rewards': 'รางวัล',
  'Rewards by game': 'รางวัลตามเกม',
  'Rows': 'แถว',
  'Sales': 'ยอดขาย',
  'Sales by game': 'ยอดขายตามเกม',
  'Sales by partner store': 'ยอดขายตามร้านค้าพาร์ทเนอร์',
  'Scope': 'Scope',
  'Segment': 'ชุดเลข',
  'Select': 'เลือก',
  'Settlement by partner store': 'การชำระบัญชีตามร้านค้าพาร์ทเนอร์',
  'Settlement status mix': 'สัดส่วนสถานะการชำระบัญชี',
  'Share': 'สัดส่วน',
  'Sold': 'ขายแล้ว',
  'Sold stock': 'สต็อกที่ขายแล้ว',
  'Sold tickets': 'สลากที่ขายแล้ว',
  'Status': 'สถานะ',
  'Stock': 'คลังสลาก',
  'Stock by game': 'คลังสลากตามเกม',
  'Stock by partner store': 'คลังสลากตามร้านค้าพาร์ทเนอร์',
  'Stock status breakdown': 'สถานะคลังสลาก',
  'Store': 'ร้านค้า',
  'Store code': 'รหัสร้านค้า',
  'Store status': 'สถานะร้านค้า',
  'Stores': 'ร้านค้า',
  'Submitted': 'เวลาส่งคำขอ',
  'Target': 'เป้าหมาย',
  'Tickets': 'สลาก',
  'To': 'ถึง',
  'Top partner stores by sales': 'ร้านค้าพาร์ทเนอร์ยอดขายสูงสุด',
  'Total': 'รวม',
  'Transactions': 'รายการธุรกรรม',
  'Type': 'ประเภท',
  'Unique numbers': 'จำนวนเลขไม่ซ้ำ',
  'Updated': 'อัปเดตล่าสุด',
  'Usage by partner store': 'การใช้งานตามร้านค้าพาร์ทเนอร์',
  'Wallet flow by partner store': 'กระแสเงินกระเป๋าตามร้านค้าพาร์ทเนอร์',
  'Wallet flow by reference': 'กระแสเงินกระเป๋าตามอ้างอิง',
  'Wallet net': 'กระเป๋าสุทธิ',
  'Wallet status breakdown': 'สถานะรายการกระเป๋าเงิน',
}

const metricLabels: Record<string, string> = {
  active_partners_total: 'พาร์ทเนอร์ที่ใช้งานอยู่',
  active_tenants_total: 'ร้านค้าที่ใช้งานอยู่',
  affiliate_payout_total: 'ยอดจ่าย Affiliate',
  audit_events_count: 'จำนวนเหตุการณ์ Audit',
  average_order_amount: 'ยอดเฉลี่ยต่อคำสั่งซื้อ',
  customers_count: 'จำนวนลูกค้า',
  customers_total: 'ลูกค้าทั้งหมด',
  new_customers_count: 'ลูกค้าใหม่',
  orders_count: 'จำนวนคำสั่งซื้อ',
  paid_customer_count: 'ลูกค้าที่ซื้อแล้ว',
  paid_orders_count: 'คำสั่งซื้อที่ชำระแล้ว',
  partners_total: 'พาร์ทเนอร์ทั้งหมด',
  payout_total: 'ยอดจ่ายเงิน',
  reward_adjustment_total: 'ยอดปรับรางวัล',
  reward_base_total: 'เงินรางวัลฐาน',
  reward_claims_count: 'จำนวนคำขอขึ้นเงินรางวัล',
  reward_payout_total: 'ยอดจ่ายรางวัล',
  sales_total: 'ยอดขายรวม',
  selling_tenant_count: 'จำนวนร้านค้าที่ขายได้',
  settlement_net_total: 'ยอดชำระบัญชีสุทธิ',
  settlements_count: 'จำนวนรายการชำระบัญชี',
  stock_available_count: 'สต็อกพร้อมขาย',
  stock_count: 'จำนวนสต็อก',
  stock_sold_count: 'สต็อกขายแล้ว',
  stock_total_count: 'สต็อกทั้งหมด',
  tenants_total: 'ร้านค้าทั้งหมด',
  tickets_sold_count: 'จำนวนสลากที่ขายได้',
  wallet_inflow_total: 'เงินเข้ากระเป๋า',
  wallet_ledger_total: 'ยอดรวมบัญชีกระเป๋าเงิน',
  wallet_net_flow_total: 'กระแสเงินสุทธิกระเป๋า',
  wallet_outflow_total: 'เงินออกจากกระเป๋า',
  api_request_count: 'จำนวน API',
  booking_request_count: 'จำนวนจอง',
  checkout_request_count: 'จำนวนชำระเงิน',
  order_count: 'จำนวนคำสั่งซื้อ',
  customer_count: 'จำนวนลูกค้า',
  ticket_count: 'จำนวนสลาก',
  transaction_count: 'จำนวนธุรกรรม',
  row_count: 'จำนวนแถว',
  event_count: 'จำนวนเหตุการณ์',
  admin_count: 'จำนวนผู้ดูแล',
  claim_count: 'จำนวนคำขอ',
  approved_count: 'อนุมัติแล้ว',
  rejected_count: 'ปฏิเสธแล้ว',
  enabled_count: 'เปิดใช้งาน',
  with_pin_count: 'ตั้ง PIN แล้ว',
  auto_reward_count: 'ขึ้นเงินอัตโนมัติ',
}

const enumValues: Record<string, string> = {
  active: 'ใช้งานอยู่',
  inactive: 'ไม่ใช้งาน',
  pending: 'รอดำเนินการ',
  pending_review: 'รอตรวจสอบ',
  approved: 'อนุมัติแล้ว',
  rejected: 'ปฏิเสธแล้ว',
  cancelled: 'ยกเลิกแล้ว',
  canceled: 'ยกเลิกแล้ว',
  completed: 'สำเร็จแล้ว',
  failed: 'ล้มเหลว',
  draft: 'ฉบับร่าง',
  paid: 'ชำระแล้ว',
  unpaid: 'ยังไม่ชำระ',
  refunded: 'คืนเงินแล้ว',
  available: 'พร้อมขาย',
  reserved: 'จองแล้ว',
  sold: 'ขายแล้ว',
  allocated: 'จัดสรรแล้ว',
  inflow: 'เงินเข้า',
  outflow: 'เงินออก',
  credit: 'เงินเข้า',
  debit: 'เงินออก',
  wallet: 'กระเป๋าเงิน',
  wallet_credit: 'โอนเข้ากระเป๋า',
  bank_transfer: 'โอนเข้าบัญชีธนาคาร',
  payment: 'ชำระเงิน',
  topup: 'เติมเงิน',
  order: 'คำสั่งซื้อ',
  reward_claim: 'คำขอขึ้นเงินรางวัล',
  commission: 'ค่าคอมมิชชัน',
  day: 'วัน',
  week: 'สัปดาห์',
  month: 'เดือน',
  game: 'เกม / งวด',
  tenant: 'ร้านค้า',
  status: 'สถานะ',
  customer: 'ลูกค้า',
  admin: 'ผู้ดูแลระบบ',
  system: 'ระบบ',
  yes: 'ใช่',
  no: 'ไม่ใช่',
  true: 'ใช่',
  false: 'ไม่ใช่',
}

const normalize = (value: unknown) => String(value ?? '').replace(/\s+/g, ' ').trim()
const isThai = (locale: unknown) => thaiLocales.has(String(locale || '').trim())

const titleizeReport = (value: string) => normalize(value)
  .replace(/[_-]/g, ' ')
  .replace(/\b\w/g, (char) => char.toUpperCase())

export const reportKeyLabel = (key: unknown, locale: unknown) => {
  const normalized = normalize(key)
  if (!isThai(locale)) {
    return titleizeReport(normalized)
  }

  return reportNames[normalized] || translateReportText(titleizeReport(normalized), locale)
}

export const reportTitle = (key: unknown, locale: unknown) => {
  const normalized = normalize(key)
  if (!isThai(locale)) {
    return `${titleizeReport(normalized)} Report`
  }

  return `รายงาน${reportKeyLabel(normalized, locale)}`
}

export const reportIndexTitle = (scope: unknown, locale: unknown) => {
  if (!isThai(locale)) {
    return `${scope === 'tenant' ? 'Tenant' : 'Central'} Reports`
  }

  return scope === 'tenant' ? 'รายงานร้านค้า' : 'รายงาน Central'
}

export const translateReportText = (value: unknown, locale: unknown) => {
  const text = normalize(value)
  if (!text || !isThai(locale)) {
    return String(value ?? '')
  }

  if (reportText[text]) {
    return reportText[text]
  }

  const lowered = text.toLowerCase()
  return enumValues[lowered] || reportNames[lowered] || String(value ?? '')
}

export const translateReportFieldLabel = (key: unknown, fallback: unknown, locale: unknown) => {
  if (!isThai(locale)) {
    return String(fallback || key || '')
  }

  const keyText = normalize(key)
  return metricLabels[keyText] || reportText[normalize(fallback)] || translateReportText(fallback || titleizeReport(keyText), locale)
}

const translateOption = (option: OperationOption, locale: unknown): OperationOption => {
  if (!isThai(locale)) {
    return option
  }

  if (typeof option === 'object' && option !== null) {
    return {
      ...option,
      label: translateReportText(option.label || option.value, locale),
    }
  }

  return {
    value: option,
    label: translateReportText(option, locale),
  }
}

export const translateReportColumns = (columns: OperationColumn[] = [], locale: unknown): OperationColumn[] => (
  columns.map((column) => ({
    ...column,
    label: translateReportFieldLabel(column.key, column.label, locale),
  }))
)

export const translateReportFilters = (filters: OperationFilter[] = [], locale: unknown): OperationFilter[] => (
  filters.map((filter) => ({
    ...filter,
    label: translateReportFieldLabel(filter.key, filter.label, locale),
    emptyOptionLabel: filter.emptyOptionLabel ? translateReportText(filter.emptyOptionLabel, locale) : filter.emptyOptionLabel,
    options: filter.options?.map((option) => translateOption(option, locale)),
  }))
)

const translateFormFields = (fields: OperationFormField[] = [], locale: unknown): OperationFormField[] => (
  fields.map((field) => ({
    ...field,
    label: translateReportFieldLabel(field.key.replace(/^filters\./, ''), field.label, locale),
    emptyOptionLabel: field.emptyOptionLabel ? translateReportText(field.emptyOptionLabel, locale) : field.emptyOptionLabel,
    rangeStartLabel: field.rangeStartLabel ? translateReportText(field.rangeStartLabel, locale) : field.rangeStartLabel,
    rangeEndLabel: field.rangeEndLabel ? translateReportText(field.rangeEndLabel, locale) : field.rangeEndLabel,
    help: field.help ? translateReportText(field.help, locale) : field.help,
    placeholder: field.placeholder ? translateReportText(field.placeholder, locale) : field.placeholder,
    options: field.options?.map((option) => translateOption(option, locale)),
  }))
)

export const translateReportActions = (actions: OperationAction[] = [], locale: unknown): OperationAction[] => (
  actions.map((action) => ({
    ...action,
    label: translateReportText(action.label, locale),
    disabledReason: action.disabledReason ? translateReportText(action.disabledReason, locale) : action.disabledReason,
    formFields: translateFormFields(action.formFields || [], locale),
  }))
)

export const translateReportValue = (value: unknown, locale: unknown) => {
  if (!isThai(locale)) {
    return String(value ?? '')
  }

  return translateReportText(value, locale)
}
