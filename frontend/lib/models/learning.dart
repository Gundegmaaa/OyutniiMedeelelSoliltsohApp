class QuizQuestion {
  const QuizQuestion(this.prompt, this.options, this.answer, this.explanation);
  final String prompt;
  final List<String> options;
  final int answer;
  final String explanation;
}

const softwareQuiz = [
  QuizQuestion(
    'OOP-д encapsulation ямар үүрэгтэй вэ?',
    [
      'Өгөгдөл ба үйлдлийг нэгтгэж, дотоод төлөвт хандахыг хязгаарлана',
      'Хүснэгтүүдийг холбоно',
      'Кодыг зөвхөн хурдан ажиллуулна',
    ],
    0,
    'Encapsulation нь өгөгдөл ба түүн дээр ажиллах үйлдлийг нэг объектод нэгтгэнэ.',
  ),
  QuizQuestion(
    'SQL-ийн SELECT командын зориулалт юу вэ?',
    ['Мөр устгах', 'Өгөгдөл унших', 'Хүснэгт устгах'],
    1,
    'SELECT нь өгөгдлийн сангаас мэдээлэл сонгон уншина.',
  ),
  QuizQuestion(
    'Веб хуудасны бүтцийг ямар хэлээр тодорхойлдог вэ?',
    ['CSS', 'SQL', 'HTML'],
    2,
    'HTML бүтцийг, CSS харагдах байдлыг тодорхойлдог.',
  ),
];

const informationQuiz = [
  QuizQuestion(
    'Мэдээллийн системийн үндсэн бүрэлдэхүүн аль нь вэ?',
    ['Зөвхөн компьютер', 'Хүн, үйл явц, өгөгдөл, технологи', 'Зөвхөн интернэт'],
    1,
    'Мэдээллийн систем нь хүн, үйл явц, өгөгдөл, технологийн уялдаа юм.',
  ),
  QuizQuestion(
    'Primary key ямар шаардлага хангах вэ?',
    [
      'Давхардсан утгатай байх',
      'Заавал текст байх',
      'Давтагдахгүй, NULL биш байх',
    ],
    2,
    'Primary key нь хүснэгтийн мөр бүрийг ялган танина.',
  ),
  QuizQuestion(
    'Шаардлагын шинжилгээний гол зорилго юу вэ?',
    [
      'Хэрэглэгчийн хэрэгцээ, системийн шаардлагыг тодорхойлох',
      'Сервер худалдаж авах',
      'Зөвхөн өнгө сонгох',
    ],
    0,
    'Шаардлагын шинжилгээ нь систем ямар хэрэгцээг хангахыг тодорхойлно.',
  ),
];

class PracticeProblem {
  const PracticeProblem(this.prompt, this.answer, this.explanation, this.xp);
  final String prompt;
  final String answer;
  final String explanation;
  final int xp;
}

const softwareProblems = [
  PracticeProblem(
    '1-ээс 10 хүртэлх бүхэл тоонуудын нийлбэр хэд вэ?',
    '55',
    '1 + 2 + … + 10 = 10 × 11 / 2 = 55.',
    20,
  ),
  PracticeProblem(
    'A = [3, 7, 2, 9, 4] массивын хамгийн их ба хамгийн бага утгын ялгавар хэд вэ?',
    '7',
    'Хамгийн их нь 9, хамгийн бага нь 2. 9 − 2 = 7.',
    40,
  ),
  PracticeProblem(
    'Өсөх эрэмбэтэй 1,024 элементтэй массивд binary search хийхэд хамгийн муу тохиолдолд хэдэн харьцуулалт хийх вэ? '
        'Давталт бүрд дундах элементийг зорилтот утгатай нэг удаа харьцуулна.',
    '11',
    '⌊log₂(1024)⌋ + 1 = 11. Үлдсэн нэг элементийг шалгах алхмыг тооцно.',
    60,
  ),
];

const informationProblems = [
  PracticeProblem(
    'Оюутны хүснэгтэд 25 мөр байна. 5 шинэ оюутан нэмбэл нийт хэдэн мөртэй болох вэ?',
    '30',
    '25 + 5 = 30 мөр.',
    20,
  ),
  PracticeProblem(
    'Захиалгын хүснэгтэд 120 мөр байна. 35 нь цуцлагдсан, 45 нь хүлээгдэж байгаа бол үлдсэн гүйцэтгэсэн захиалга хэд вэ?',
    '40',
    '120 − 35 − 45 = 40 захиалга.',
    40,
  ),
  PracticeProblem(
    'A хүснэгтэд 8 мөр, B хүснэгтэд 12 мөр байна. CROSS JOIN үр дүн хэдэн мөртэй вэ?',
    '96',
    'CROSS JOIN бүх боломжит хослолыг үүсгэнэ: 8 × 12 = 96.',
    60,
  ),
];

// One reward per activity, so repeated practice cannot inflate the demo rank.
class LearningProgress {
  final Set<String> completed = {};
  int xp = 820;
  int award(String activity, int points) {
    if (!completed.add(activity)) {
      return 0;
    }
    xp += points;
    return points;
  }

  int get rank => xp > 1250
      ? 1
      : xp > 1190
      ? 2
      : xp > 1110
      ? 3
      : 12;
}
