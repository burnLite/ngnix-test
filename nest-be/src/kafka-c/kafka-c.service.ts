import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { Kafka, Producer } from 'kafkajs';

@Injectable()
export class KafkaCService implements OnModuleInit, OnModuleDestroy {
  private kafka: Kafka;
  private producer: Producer;

  async onModuleInit() {
    this.kafka = new Kafka({
      clientId: 'k8s-nestjs',
      brokers: process.env.KAFKA_BROKERS?.split(','),
    });

    this.producer = this.kafka.producer();
    await this.producer.connect();
  }

  async onModuleDestroy() {
    await this.producer.disconnect();
  }

  async queueMessage(msg: string): Promise<void> {
    await this.producer.send({
      topic: process.env.KAFKA_TOPIC ?? 'messages',
      messages: [
        {
          value: msg,
          timestamp: Date.now().toString(),
        },
      ],
    });
  }
}
