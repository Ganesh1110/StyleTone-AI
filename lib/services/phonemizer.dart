class Phonemizer {
  static final Map<String, String> _dict = {
    // Colors
    'red': 'ɹˈɛd',
    'blue': 'blˈuː',
    'green': 'ɡɹˈiːn',
    'yellow': 'jˈɛloʊ',
    'black': 'blˈæk',
    'white': 'wˈaɪt',
    'purple': 'pˈɜːpəl',
    'orange': 'ˈɒɹɪndʒ',
    'pink': 'pˈɪŋk',
    'brown': 'bɹˈaʊn',
    'gray': 'ɡɹˈeɪ',
    'grey': 'ɡɹˈeɪ',
    'navy': 'nˈeɪvi',
    'teal': 'tˈiːl',
    'coral': 'kˈɔːɹəl',
    'mint': 'mˈɪnt',
    'lavender': 'lˈævəndɚ',
    'maroon': 'məɹˈuːn',
    'charcoal': 'tʃˈɑːɹkoʊl',
    'beige': 'bˈeɪʒ',
    'cream': 'kɹˈiːm',
    'ivory': 'ˈaɪvɚi',
    'tan': 'tˈæn',
    'olive': 'ˈɒlɪv',
    'burgundy': 'bˈɜːɡəndi',
    'mustard': 'mˈʌstɚd',
    'salmon': 'sˈæmən',
    'peach': 'pˈiːtʃ',
    'rose': 'ɹˈoʊz',
    'blush': 'blˈʌʃ',
    'mauve': 'mˈoʊv',
    'taupe': 'tˈoʊp',
    'indigo': 'ˈɪndɪɡoʊ',
    'violet': 'vˈaɪələt',
    'magenta': 'mədʒˈɛntə',
    'cyan': 'sˈaɪæn',
    'gold': 'ɡˈoʊld',
    'silver': 'sˈɪlvɚ',
    'bronze': 'bɹˈɑːnz',
    'copper': 'kˈɑːpɚ',

    // Fashion & styling
    'blazer': 'blˈeɪzɚ',
    'shirt': 'ʃˈɜːt',
    'top': 'tˈɑːp',
    'dress': 'dɹˈɛs',
    'sweater': 'swˈɛtɚ',
    'jacket': 'dʒˈækɪt',
    'trousers': 'tɹˈaʊzɚz',
    'pants': 'pˈænts',
    'jeans': 'dʒˈiːnz',
    'skirt': 'skˈɜːt',
    'suit': 'sˈuːt',
    'tie': 'tˈaɪ',
    'scarf': 'skˈɑːɹf',
    'shoes': 'ʃˈuːz',
    'accessory': 'æksˈɛsəɹi',
    'accessories': 'æksˈɛsəɹiz',
    'outfit': 'ˈaʊtfɪt',

    // Style descriptors
    'professional': 'pɹəfˈɛʃənəl',
    'elegant': 'ˈɛlɪɡənt',
    'casual': 'kˈæʒuəl',
    'formal': 'fˈɔːɹməl',
    'classic': 'klˈæsɪk',
    'bold': 'bˈoʊld',
    'neutral': 'njˈuːtɹəl',
    'neutrals': 'njˈuːtɹəlz',
    'tailored': 'tˈeɪlɚd',
    'pair': 'pˈɛɚ',
    'paired': 'pˈɛɚd',
    'wear': 'wˈɛɚ',
    'style': 'stˈaɪl',
    'stylish': 'stˈaɪlɪʃ',
    'look': 'lˈʊk',
    'looks': 'lˈʊks',
    'statement': 'stˈeɪtmənt',
    'match': 'mˈætʃ',
    'matching': 'mˈætʃɪŋ',
    'combine': 'kəmbˈaɪn',
    'combines': 'kəmbˈaɪnz',

    // Common words
    'your': 'jˈɔːɹ',
    'our': 'ˈaʊɚ',
    'the': 'ðə',
    'a': 'ə',
    'an': 'ən',
    'is': 'ˈɪz',
    'are': 'ˈɑːɹ',
    'for': 'fˈɔːɹ',
    'as': 'ˈæz',
    'on': 'ˈɒn',
    'it': 'ˈɪt',
    'at': 'ˈæt',
    'with': 'wˈɪð',
    'from': 'fɹˈʌm',
    'like': 'lˈaɪk',
    'this': 'ðˈɪs',
    'that': 'ðˈæt',
    'and': 'ənd',
    'or': 'ˈɔːɹ',
    'but': 'bˈʌt',
    'not': 'nˈɒt',
    'all': 'ˈɔːl',
    'can': 'kˈæn',
    'will': 'wˈɪl',
    'very': 'vˈɛɹi',
    'more': 'mˈɔːɹ',
    'most': 'mˈoʊst',
    'some': 'sˈʌm',
    'any': 'ˈɛni',
    'keep': 'kˈiːp',
    'make': 'mˈeɪk',
    'let': 'lˈɛt',
    'get': 'ɡˈɛt',
    'use': 'jˈuːz',
    'try': 'tɹˈaɪ',
    'add': 'ˈæd',
    'choose': 'tʃˈuːz',
    'great': 'ɡɹˈeɪt',
    'best': 'bˈɛst',
    'perfect': 'pˈɜːfɪkt',
    'beautiful': 'bjˈuːtɪfəl',
    'nice': 'nˈaɪs',
    'good': 'ɡˈʊd',
    'better': 'bˈɛtɚ',
    'feel': 'fˈiːl',
    'color': 'kˈʌlɚ',
    'colors': 'kˈʌlɚz',
    'colour': 'kˈʌlɚ',
    'palette': 'pˈælɪt',
    'shade': 'ʃˈeɪd',
    'tone': 'tˈoʊn',
    'hue': 'hjˈuː',
    'wearable': 'wˈɛɹəbəl',
    'complementary': 'kˌɑːmplɪmˈɛntəɹi',
    'contrast': 'kəntɹˈæst',
    'vibrant': 'vˈaɪbɹənt',
    'soft': 'sˈɒft',
    'warm': 'wˈɔːɹm',
    'cool': 'kˈuːl',
    'light': 'lˈaɪt',
    'dark': 'dˈɑːɹk',
    'bright': 'bɹˈaɪt',
    'pale': 'pˈeɪl',
    'rich': 'ɹˈɪtʃ',
    'deep': 'dˈiːp',
    'sleek': 'slˈiːk',
    'polished': 'pˈɑːlɪʃt',
    'sophisticated': 'səfˈɪstɪkeɪtɪd',
    'modern': 'mˈɑːdɚn',
    'trendy': 'tɹˈɛndi',
    'chic': 'ʃˈiːk',
    'effortless': 'ˈɛfɚtlɪs',
    'effortlessly': 'ˈɛfɚtlɪsli',
    'confidence': 'kˈɑːnfɪdəns',
    'confident': 'kˈɑːnfɪdənt',
    'yourself': 'jɚsˈɛlf',
    'ensemble': 'ɑːnsˈɑːmbəl',
    'wardrobe': 'wˈɔːɹdɹoʊb',
    'fashion': 'fˈæʃən',
    'season': 'sˈiːzən',
    'summer': 'sˈʌmɚ',
    'winter': 'wˈɪntɚ',
    'spring': 'sprˈɪŋ',
    'autumn': 'ˈɔːtəm',
    'fall': 'fˈɔːl',
    'evening': 'ˈiːvnɪŋ',
    'day': 'dˈeɪ',
    'night': 'nˈaɪt',
  };

  String toPhonemes(String text) {
    final lowercase = text.toLowerCase().trim();
    final words = lowercase.split(RegExp(r'\s+'));
    final phonemes = words.map(_wordToPhonemes).join(' ');
    return phonemes;
  }

  String _wordToPhonemes(String word) {
    if (_dict.containsKey(word)) {
      return _dict[word]!;
    }
    return _ruleBasedPhonemes(word);
  }

  String _ruleBasedPhonemes(String word) {
    if (word.isEmpty) return '';
    if (word.length == 1) {
      return _letterToPhoneme(word);
    }
    final buffer = StringBuffer();
    int i = 0;
    while (i < word.length) {
      if (i + 2 <= word.length) {
        final digraph = word.substring(i, i + 2);
        final ph = _digraphToPhoneme(digraph);
        if (ph != null) {
          buffer.write(ph);
          i += 2;
          continue;
        }
      }
      if (i + 1 <= word.length) {
        final ch = word[i];
        buffer.write(_letterToPhoneme(ch));
        i += 1;
      }
    }
    return buffer.toString();
  }

  String? _digraphToPhoneme(String pair) {
    switch (pair) {
      case 'sh':
        return 'ʃ';
      case 'ch':
        return 'tʃ';
      case 'th':
        return 'θ';
      case 'wh':
        return 'w';
      case 'ph':
        return 'f';
      case 'gh':
        return '';
      case 'ck':
        return 'k';
      case 'ng':
        return 'ŋ';
      case 'qu':
        return 'kw';
      case 'ea':
        return 'ˈiː';
      case 'ee':
        return 'ˈiː';
      case 'oo':
        return 'ˈuː';
      case 'ou':
        return 'ˈaʊ';
      case 'oi':
        return 'ˈɔɪ';
      case 'ai':
        return 'ˈeɪ';
      case 'ay':
        return 'ˈeɪ';
      case 'ie':
        return 'ˈaɪ';
      case 'oa':
        return 'ˈoʊ';
      case 'ui':
        return 'ˈuː';
      case 'ua':
        return 'wə';
      case 'ue':
        return 'ˈuː';
      default:
        return null;
    }
  }

  String _letterToPhoneme(String letter) {
    switch (letter) {
      case 'a':
        return 'ə';
      case 'b':
        return 'b';
      case 'c':
        return 'k';
      case 'd':
        return 'd';
      case 'e':
        return 'ˈɛ';
      case 'f':
        return 'f';
      case 'g':
        return 'ɡ';
      case 'h':
        return 'h';
      case 'i':
        return 'ˈɪ';
      case 'j':
        return 'dʒ';
      case 'k':
        return 'k';
      case 'l':
        return 'l';
      case 'm':
        return 'm';
      case 'n':
        return 'n';
      case 'o':
        return 'ˈɑː';
      case 'p':
        return 'p';
      case 'q':
        return 'k';
      case 'r':
        return 'ɹ';
      case 's':
        return 's';
      case 't':
        return 't';
      case 'u':
        return 'ˈʌ';
      case 'v':
        return 'v';
      case 'w':
        return 'w';
      case 'x':
        return 'ks';
      case 'y':
        return 'j';
      case 'z':
        return 'z';
      default:
        return letter;
    }
  }
}
