class ChoiceModel {
  final int id;
  final String text;
  // Null until the reveal — the server never sends the correct answer down
  // before every player has answered, so this stays unknown until then.
  final bool? correct;

  const ChoiceModel({
    required this.id,
    required this.text,
    this.correct,
  });

  factory ChoiceModel.fromJson(Map<String, dynamic> json) {
    return ChoiceModel(
      id: json['id'] as int,
      text: json['text'] as String,
      correct: json['correct'] as bool?,
    );
  }

  ChoiceModel copyWith({bool? correct}) {
    return ChoiceModel(id: id, text: text, correct: correct ?? this.correct);
  }
}

class QuestionModel {
  final int id;
  final int chapter;
  final String subject;
  final String question;
  final List<ChoiceModel> choices;
  // Null until the reveal, same as ChoiceModel.correct above.
  final String? explanation;

  const QuestionModel({
    required this.id,
    required this.chapter,
    required this.subject,
    required this.question,
    required this.choices,
    this.explanation,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as int,
      chapter: json['chapter'] as int,
      subject: json['subject'] as String,
      question: json['question'] as String,
      choices: (json['choices'] as List<dynamic>)
          .map((c) => ChoiceModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      explanation: json['explanation'] as String?,
    );
  }

  /// Returns a copy of this question with the correct choice + explanation
  /// filled in, used once the server sends the post-reveal payload.
  QuestionModel revealedWith({
    required int correctChoiceId,
    required String explanation,
  }) {
    return QuestionModel(
      id: id,
      chapter: chapter,
      subject: subject,
      question: question,
      explanation: explanation,
      choices: choices
          .map((c) => c.copyWith(correct: c.id == correctChoiceId))
          .toList(),
    );
  }
}
