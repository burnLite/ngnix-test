import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { KafkaCModule } from './kafka-c/kafka-c.module';

@Module({
  imports: [KafkaCModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
