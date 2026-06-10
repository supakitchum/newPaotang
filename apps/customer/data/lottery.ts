export const drawDate = '2 พ.ค. 2569'
export const resultDate = '16 เม.ย. 2569'
export const ticketPrice = 80

export const luckyDigits = ['1', '2', '3', '4', '5', '6']

export const currentResults = {
  first: '309612',
  front3: ['108', '355'],
  last2: '77',
  last3: ['424', '868'],
  nearFirst: ['309611', '309613'],
  second: ['097722', '175203', '419269', '482398', '554697'],
  third: ['136798', '366037', '443166', '575200', '742087', '746898', '753452', '806727', '870392', '916619']
}

export const pastResults = [
  {
    date: '1 เม.ย. 2569',
    first: '292514',
    front3: ['113', '406'],
    last2: '47',
    last3: ['098', '851']
  },
  {
    date: '16 มี.ค. 2569',
    first: '833009',
    front3: ['827', '732'],
    last2: '64',
    last3: ['335', '732']
  }
]

export const lotteries = [
  { number: '194463', seller: 'ดวงเดือน ลอตเตอรี่', draw: 57, set: 20, selected: true },
  { number: '360283', seller: 'ชนิศา มานั่งคั่ง', draw: 57, set: 17 },
  { number: '925649', seller: 'สำราญ', draw: 57, set: 11 },
  { number: '128604', seller: 'สมฤทธิ์ ลอตเตอรี่ Vip', draw: 57, set: 22 },
  { number: '683058', seller: 'พรชนกพารวย', draw: 57, set: 17 },
  { number: '804473', seller: 'นรัตมน์', draw: 57, set: 27 },
  { number: '507703', seller: 'นรัตมน์', draw: 57, set: 28 },
  { number: '249299', seller: 'นรัตมน์', draw: 57, set: 27 },
  { number: '873622', seller: 'ชีวิตยังมีเลขใหม่เสมอ', draw: 57, set: 30, highlight: '22' },
  { number: '775522', seller: 'มุ่ง888', draw: 57, set: 29, highlight: '22' },
  { number: '636622', seller: 'สุวิทย์พารวย', draw: 57, set: 30, highlight: '22' }
]

export const moreNumberTickets = [
  { number: '010799', seller: 'คุณหนึ่ง สลากดิจิทัล', draw: 57, set: 9 },
  { number: '010799', seller: 'ขวัญเมืองมหาเฮง', draw: 57, set: 22 },
  { number: '010799', seller: 'เพลินตา ขันรักษ์', draw: 57, set: 30 },
  { number: '010799', seller: 'พอใจรวย', draw: 57, set: 10 },
  { number: '010799', seller: 'ถูกทุกงวด', draw: 57, set: 23 }
]

export const stores = [
  'นรัตมน์',
  'บุญศรี 999',
  'ศักดิ์ล๊อตโต้',
  'โชคดี บีบี สลากออนไลน์',
  'สมาร์ท ล็อตเตอรี่ 777',
  'เส้นทางรวย 1'
]

export const banks = [
  { name: 'กรุงไทย', tone: '#00a7e0' },
  { name: 'ไทยพาณิชย์', tone: '#4b168c' },
  { name: 'กสิกรไทย', tone: '#08a94f' },
  { name: 'ทีเอ็มบีธนชาต', tone: '#f66b14' },
  { name: 'กรุงเทพ', tone: '#07118b' },
  { name: 'กรุงศรีอยุธยา', tone: '#7b6d70' },
  { name: 'ออมสิน', tone: '#ed008c' },
  { name: 'ธ.ก.ส.', tone: '#19418b' },
  { name: 'ยู โอ บี', tone: '#ffffff' },
  { name: 'ไอแบงก์', tone: '#06461d' }
]

export const thaiBankOptions = [
  'ธนาคารกรุงเทพ',
  'ธนาคารกสิกรไทย',
  'ธนาคารกรุงไทย',
  'ธนาคารทหารไทยธนชาต',
  'ธนาคารไทยพาณิชย์',
  'ธนาคารกรุงศรีอยุธยา',
  'ธนาคารเกียรตินาคินภัทร',
  'ธนาคารซีไอเอ็มบี ไทย',
  'ธนาคารทิสโก้',
  'ธนาคารยูโอบี',
  'ธนาคารไทยเครดิต',
  'ธนาคารแลนด์ แอนด์ เฮ้าส์',
  'ธนาคารไอซีบีซี (ไทย)',
  'ธนาคารออมสิน',
  'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร',
  'ธนาคารอาคารสงเคราะห์',
  'ธนาคารอิสลามแห่งประเทศไทย',
  'ธนาคารพัฒนาวิสาหกิจขนาดกลางและขนาดย่อมแห่งประเทศไทย'
]

export const menuSections = [
  {
    title: 'ประวัติ',
    items: [{ label: 'กระเป๋าเงิน', to: '/my-wallet' }, { label: 'ประวัติการซื้อสลากฯ', to: '/purchase-history' }, { label: 'ประวัติขึ้นเงินรางวัลสลากดิจิทัล', to: '/reward-claims' }, { label: 'กิจกรรม', to: '/activities', badge: 'ใหม่' }, { label: 'ระบบตัวแทนจำหน่าย', to: '/affiliate' }]
  },
  {
    title: 'ตั้งค่ารับเงินรางวัล',
    items: [{ label: 'ช่องทางรับเงินรางวัล', to: '/profile/reward-bank' }, { label: 'ขึ้นเงินรางวัลอัตโนมัติ', to: '/profile/auto-reward', badge: 'แนะนำ' }, { label: 'แจ้งเตือนผ่าน LINE', to: '/profile/line-notifications' }]
  },
  {
    title: 'เกี่ยวกับแอปฯ GLO',
    items: [{ label: 'ข่าวสาร', to: '/news' }, { label: 'ข้อตกลงและเงื่อนไข', to: '/terms' }, { label: 'ข้อควรรู้การซื้อ-ขายสลากฯ', to: '/lottery-knowledge' }, 'วิธีซื้อขายสลากฯ และการติดต่อ']
  }
]
