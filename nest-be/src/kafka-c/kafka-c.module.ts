import { Module } from '@nestjs/common';
import { KafkaCController } from './kafka-c.controller';
import { KafkaCService } from './kafka-c.service';

@Module({
  controllers: [KafkaCController],
  providers: [KafkaCService]
})
export class KafkaCModule {}
