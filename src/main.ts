import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import {
  ApiErrorResponseDto,
  ApiResponseDto,
} from './common/dto/api-response.dto';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformResponseInterceptor } from './common/interceptors/transform-response.interceptor';
import { httpRequestLoggerMiddleware } from './common/middleware/http-request-logger.middleware';
import { DatabaseService } from './database/database.service';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  app.enableCors({
    origin: true,
    credentials: true,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  });

  app.use(httpRequestLoggerMiddleware);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.useGlobalInterceptors(new TransformResponseInterceptor());
  app.useGlobalFilters(new HttpExceptionFilter());

  const swaggerConfig = new DocumentBuilder()
    .setTitle('API Sistema Sarita')
    .setDescription('API REST del sistema Sarita')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig, {
    extraModels: [ApiResponseDto, ApiErrorResponseDto],
  });
  SwaggerModule.setup('api/docs', app, document);

  const db = app.get(DatabaseService);
  const dbInfo = db.getConnectionInfo();
  const dbConnected = await db.checkConnection();

  const port = process.env.PORT ?? 3000;
  await app.listen(port);

  logger.log('-------------------------------------------');
  logger.log(`API iniciada en: http://localhost:${port}`);
  logger.log(`Swagger docs en: http://localhost:${port}/api/docs`);
  logger.log(
    `Base de datos: ${dbConnected ? 'conectada' : 'sin conexión'} ` +
      `(${dbInfo.host}:${dbInfo.port}/${dbInfo.database} | user: ${dbInfo.user})`,
  );
  logger.log('-------------------------------------------');
}

bootstrap();