import 'package:app_clinica_estetica/core/data/models/service_model.dart';

class ServicesData {
  static final List<ServiceModel> mockServices = [
    ServiceModel(
      id: '1',
      nome: 'Limpeza de Pele Profunda',
      descricao: 'Remoção de impurezas e revitalização facial completa.',
      preco: 120.0,
      duracaoMinutos: 60,
      categoriaId: 'ROSTO',
      imagemUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDghgOrF35ZoCk6Qmyu6t61hMibKufGBsw18qoRqieAWh1wt-LLLI9Pbuplao7S5jeH7XKXSp7H7W3wa-V0iyHX__EdSsfmpkwDWKa8e8P1C5d7mw1B8ffE2JOTtARmPl33BPKyh8hmi2LX3NcyjQPJY8J89E4U82qlyHS07VTJ0OKiFu-hHOxZRFlSBtEnYy44-h6cHM5a1HRS3YFVS9y_h5Gi_wQpQdwkoagRsFmIiy96g4Na6G1y0u6DJVDq8FrAjh3kbC6_wJhq',
    ),
    ServiceModel(
      id: '2',
      nome: 'Botox (Toxina Botulínica)',
      descricao: 'Redução de linhas de expressão e rugas dinâmicas.',
      preco: 600.0,
      duracaoMinutos: 30,
      categoriaId: 'INJETÁVEIS',
      imagemUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDFBAEClvy-396J5IrKApNma491Fscgtk-brmAfbrNHKYqoKNE99My-HAF9u0ra1-X9jEgduB63p02rit-ascPKUKTVeswTiDUthqffxp2Q60sWkF88qLLoTXLbh_FYh_1updenljfn3qb6pFDaYo2djJfweDtEuQIiGjhN-6IxTeYauYjYUoEByKk27O4D8Ohe8w-CNe2weKuQ0bIzaVZYwxydBKJpJTXVPAl32WCrqCJuPtCLz-eIOycQBiYKLN5t8RQzV2jzryM1',
    ),
    ServiceModel(
      id: '3',
      nome: 'Preenchimento Facial',
      descricao: 'Volume e contorno facial com ácido hialurônico.',
      preco: 900.0,
      duracaoMinutos: 45,
      categoriaId: 'INJETÁVEIS',
      imagemUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDghgOrF35ZoCk6Qmyu6t61hMibKufGBsw18qoRqieAWh1wt-LLLI9Pbuplao7S5jeH7XKXSp7H7W3wa-V0iyHX__EdSsfmpkwDWKa8e8P1C5d7mw1B8ffE2JOTtARmPl33BPKyh8hmi2LX3NcyjQPJY8J89E4U82qlyHS07VTJ0OKiFu-hHOxZRFlSBtEnYy44-h6cHM5a1HRS3YFVS9y_h5Gi_wQpQdwkoagRsFmIiy96g4Na6G1y0u6DJVDq8FrAjh3kbC6_wJhq',
    ),
  ];
}
