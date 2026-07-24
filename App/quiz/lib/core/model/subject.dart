
class SubjectModel {
  final String subject;
  final List<int> chapters;
  final int questionCount;

  const SubjectModel({
    required this.subject,
    required this.chapters,
    required this.questionCount,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      subject: json['subject'] as String,
      chapters: (json['chapters'] as List<dynamic>)
          .map((c) => c as int)
          .toList(),
      questionCount: json['questionCount'] as int? ?? 0,
    );
  }
}
